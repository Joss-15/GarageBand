#!/usr/bin/env python3
"""
map_song.py - Mapea una canción a mano, tocándola en la terminal.

Se escucha la canción y tú presionas A S D F G (carriles 1 a 5) al ritmo de lo que
quieras que sea una nota. La herramienta anota el segundo exacto de cada pulsación
respecto al audio y guarda el JSON en el mismo formato que usa el juego.

Uso (desde la carpeta del proyecto):
    python tools/map_song.py                       (pregunta canción e instrumento)
    python tools/map_song.py femtanyl guitarra     (carpeta dentro de songs/ e instrumento)

Instrumentos: base | guitarra | bajo | bateria | microfono
    "base" escribe <cancion>.json, que el juego usa cuando un instrumento no tiene mapa propio.
    Los demás escriben <cancion>_<instrumento>.json.

En Windows no hay que instalar nada (usa winsound, que ya viene con Python). Si tienes
pygame o pygame-ce instalado lo usa en su lugar, y solo con él funciona --from.

Opciones:
    --from SEG      (solo con pygame) empieza a escuchar desde ese segundo y conserva las
                    notas anteriores del mapa existente (para corregir o continuar una parte)
    --offset MS     adelanta las notas MS milisegundos (si al jugar se sienten tarde;
                    tu reacción y la latencia del audio hacen que se toque un poco después)
    --bpm N         BPM del mapa (por defecto el del mapa existente, o 120)
    --keys ASDFG    las 5 teclas de los carriles 1 a 5

Mientras suena:
    A S D F G    marcar una nota en el carril 1 a 5
    Retroceso    borrar la última nota marcada
    Esc          terminar (pregunta si guardar)
Toca cada nota con un golpe corto; mantener la tecla apretada no cuenta como nueva nota.
"""
import argparse
import json
import os
import shutil
import struct
import sys
import time
import wave

try:
    import pygame
except ImportError:
    pygame = None

try:
    import winsound
except ImportError:
    winsound = None

if pygame is None and winsound is None:
    sys.exit("No hay con qué reproducir audio. Instala pygame-ce:  pip install pygame-ce")

HERE = os.path.dirname(os.path.abspath(__file__))
SONGS_DIR = os.path.normpath(os.path.join(HERE, "..", "songs"))

# nombre en la terminal -> sufijo del archivo (el juego usa "batería" con acento)
INSTRUMENTS = {
    "base": None,
    "guitarra": "guitarra",
    "bajo": "bajo",
    "bateria": "batería",
    "microfono": "microfono",
}
LANE_COUNT = 5
DEBOUNCE = 0.06      # segundos: ignora la misma tecla repetida por mantenerla apretada
COUNTDOWN = 3


# ── Lectura de teclas sin esperar Enter ──────────────────────────────────────

if os.name == "nt":
    import msvcrt

    class Keys:
        def __enter__(self):
            return self

        def __exit__(self, *_):
            pass

        def poll(self):
            """Devuelve un carácter, "" para una tecla especial, o None si no hay nada."""
            if not msvcrt.kbhit():
                return None
            ch = msvcrt.getwch()
            if ch in ("\x00", "\xe0"):
                msvcrt.getwch()
                return ""
            return ch

        def flush(self):
            while msvcrt.kbhit():
                msvcrt.getwch()
else:
    import select
    import termios
    import tty

    class Keys:
        def __enter__(self):
            self.fd = sys.stdin.fileno()
            self.old = termios.tcgetattr(self.fd)
            tty.setcbreak(self.fd)
            return self

        def __exit__(self, *_):
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old)

        def poll(self):
            if select.select([sys.stdin], [], [], 0)[0]:
                return sys.stdin.read(1)
            return None

        def flush(self):
            while self.poll() is not None:
                pass


# ── Audio ────────────────────────────────────────────────────────────────────

def wav_length(path):
    """Duración de un .wav en segundos, también para formatos que wave no abre (24 bits, float)."""
    try:
        with wave.open(path, "rb") as w:
            return w.getnframes() / float(w.getframerate())
    except (wave.Error, EOFError):
        pass
    with open(path, "rb") as f:
        if f.read(12)[:4] != b"RIFF":
            raise ValueError("No es un WAV válido")
        rate = channels = bits = 0
        while True:
            hdr = f.read(8)
            if len(hdr) < 8:
                break
            cid, size = hdr[:4], struct.unpack("<I", hdr[4:])[0]
            if cid == b"fmt ":
                chunk = f.read(size)
                channels, rate = struct.unpack("<HI", chunk[2:8])
                bits = struct.unpack("<H", chunk[14:16])[0]
            elif cid == b"data":
                return size / float(rate * channels * (bits // 8))
            else:
                f.seek(size + (size & 1), 1)
    raise ValueError("No encontré la duración del WAV")


class PygameAudio:
    can_seek = True

    def __init__(self):
        pygame.mixer.init()

    def length(self, path):
        return pygame.mixer.Sound(path).get_length()

    def play(self, path, start=0.0):
        pygame.mixer.music.load(path)
        pygame.mixer.music.play(start=start)

    def busy(self):
        return pygame.mixer.music.get_busy()

    def stop(self):
        pygame.mixer.music.stop()


class WinsoundAudio:
    can_seek = False

    def __init__(self):
        self._end = 0.0
        self._len = 0.0

    def length(self, path):
        self._len = wav_length(path)
        return self._len

    def play(self, path, start=0.0):
        winsound.PlaySound(path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        self._end = time.perf_counter() + self._len

    def busy(self):
        return time.perf_counter() < self._end

    def stop(self):
        winsound.PlaySound(None, winsound.SND_PURGE)


def make_audio():
    if pygame is not None:
        try:
            return PygameAudio()
        except Exception:
            if winsound is None:
                raise
    return WinsoundAudio()


# ── Canciones ────────────────────────────────────────────────────────────────

def find_wav(folder):
    for f in sorted(os.listdir(folder)):
        if f.lower().endswith(".wav"):
            return os.path.join(folder, f)
    return None


def list_songs():
    songs = []
    if os.path.isdir(SONGS_DIR):
        for d in sorted(os.listdir(SONGS_DIR)):
            full = os.path.join(SONGS_DIR, d)
            if os.path.isdir(full) and find_wav(full):
                songs.append(d)
    return songs


def choose(prompt, options):
    for i, o in enumerate(options, 1):
        print(f"  {i}) {o}")
    while True:
        raw = input(prompt).strip()
        if raw.isdigit() and 1 <= int(raw) <= len(options):
            return options[int(raw) - 1]
        if raw in options:
            return raw
        print("  Opción no válida.")


def map_path(wav, instrument):
    base = os.path.splitext(wav)[0]
    suffix = INSTRUMENTS[instrument]
    return base + ".json" if suffix is None else f"{base}_{suffix}.json"


def load_existing(path):
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


# ── Grabación ────────────────────────────────────────────────────────────────

def fmt(t):
    t = max(0, int(t))
    return f"{t // 60:02d}:{t % 60:02d}"


def record(audio, wav, duration, keys, start_at, offset_s, notes):
    """Reproduce la canción y devuelve True si terminó bien (False si se canceló)."""
    key_to_lane = {k.lower(): i for i, k in enumerate(keys)}
    last_press = {}
    last_text = ""

    print("\nPrepara las manos: A S D F G.  Esc termina, Retroceso borra la última nota.")
    with Keys() as kb:
        for n in range(COUNTDOWN, 0, -1):
            print(f"  {n}...", end="\r", flush=True)
            time.sleep(1.0)
        print("  ¡YA!   ")
        kb.flush()

        try:
            audio.play(wav, start_at)
        except Exception as e:
            if start_at > 0:
                print(f"No se pudo empezar a mitad de la canción ({e}). Quita --from.")
                return False
            raise
        t0 = time.perf_counter() - start_at
        last_status = 0.0

        while True:
            now = time.perf_counter()
            song_t = now - t0

            ch = kb.poll()
            if ch:
                # el tiempo se toma justo al detectar la tecla
                press_t = time.perf_counter() - t0
                key = ch.lower()
                if ch == "\x1b":
                    audio.stop()
                    return False
                if ch in ("\x08", "\x7f"):
                    if notes:
                        gone = notes.pop()
                        last_text = f"borrada: carril {gone['lane'] + 1} ({gone['time']:.2f}s)"
                elif key in key_to_lane:
                    lane = key_to_lane[key]
                    if press_t - last_press.get(lane, -1.0) >= DEBOUNCE:
                        last_press[lane] = press_t
                        notes.append({"time": round(max(press_t - offset_s, 0.0), 4), "lane": lane})
                        last_text = f"carril {lane + 1} ({key.upper()})"
                last_status = 0.0

            if now - last_status >= 0.1:
                last_status = now
                line = f"  {fmt(song_t)} / {fmt(duration)}   notas: {len(notes):4d}   última: {last_text}"
                print(line.ljust(78), end="\r", flush=True)

            if song_t > 1.0 and not audio.busy():
                print()
                return True
            time.sleep(0.001)


def save(wav, notes, duration, bpm, out_path):
    notes = sorted(notes, key=lambda n: (n["time"], n["lane"]))
    data = {
        "cancion": os.path.basename(wav),
        "bpm_estimado": round(bpm, 2),
        "duration": round(duration, 2),
        "note_count": len(notes),
        "notes": notes,
    }
    if os.path.exists(out_path):
        shutil.copyfile(out_path, out_path + ".bak")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return len(notes)


def main():
    ap = argparse.ArgumentParser(description="Mapea una canción tocándola en la terminal.")
    ap.add_argument("song", nargs="?", help="carpeta dentro de songs/")
    ap.add_argument("instrument", nargs="?", choices=list(INSTRUMENTS), help="instrumento del mapa")
    ap.add_argument("--from", dest="start", type=float, default=0.0, help="segundo desde el que empezar")
    ap.add_argument("--offset", type=float, default=0.0, help="milisegundos que se adelantan las notas")
    ap.add_argument("--bpm", type=float, default=0.0, help="BPM del mapa")
    ap.add_argument("--keys", default="asdfg", help="5 teclas de los carriles (por defecto asdfg)")
    args = ap.parse_args()

    if len(args.keys) != LANE_COUNT or len(set(args.keys.lower())) != LANE_COUNT:
        sys.exit("--keys necesita exactamente 5 teclas distintas.")

    songs = list_songs()
    if not songs:
        sys.exit(f"No hay canciones con .wav en {SONGS_DIR}")
    song = args.song
    if song is None:
        print("Canciones:")
        song = choose("Elige canción (número): ", songs)
    folder = os.path.join(SONGS_DIR, song)
    wav = find_wav(folder) if os.path.isdir(folder) else None
    if wav is None:
        sys.exit(f"No encontré un .wav en {folder}")

    instrument = args.instrument
    if instrument is None:
        print("Instrumentos:")
        instrument = choose("Elige instrumento (número): ", list(INSTRUMENTS))

    audio = make_audio()
    if args.start > 0 and not audio.can_seek:
        sys.exit("--from necesita pygame o pygame-ce (pip install pygame-ce).")

    out_path = map_path(wav, instrument)
    existing = load_existing(out_path)

    notes = []
    if existing and args.start > 0:
        notes = [n for n in existing.get("notes", []) if float(n["time"]) < args.start]
        print(f"Conservo {len(notes)} notas anteriores a {args.start:.1f}s del mapa existente.")
    elif existing:
        print(f"Ya existe {os.path.basename(out_path)}: se reemplazará (queda copia .bak).")

    bpm = args.bpm or (float(existing["bpm_estimado"]) if existing and "bpm_estimado" in existing else 120.0)

    duration = audio.length(wav)
    print(f"\n{os.path.basename(wav)}  ·  {instrument}  ·  {fmt(duration)}  ·  BPM {bpm:g}")
    print(f"Archivo de salida: {out_path}")

    finished = record(audio, wav, duration, args.keys, args.start, args.offset / 1000.0, notes)
    print()
    if not finished:
        print(f"Terminaste antes de que acabara la canción ({len(notes)} notas).")
    if not notes:
        print("No marcaste ninguna nota; no se guarda nada.")
        return
    answer = input(f"¿Guardar {len(notes)} notas? [S/n]: ").strip().lower()
    if answer in ("", "s", "si", "sí", "y", "yes"):
        total = save(wav, notes, duration, bpm, out_path)
        print(f"Guardado: {out_path}  ({total} notas)")
    else:
        print("No se guardó.")


if __name__ == "__main__":
    main()
