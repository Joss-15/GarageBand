import os
import json
import librosa
import numpy as np
import subprocess

def separate_audio_stems(audio_file_path, output_dir):
    """
    Separa el audio en 4 instrumentos aislados utilizando Demucs (Meta AI).
    """
    print(f"\n[2/4] Separando pistas con Demucs para '{audio_file_path}'...")
    command = [
        "python", "-m", "demucs",
        "-n", "htdemucs",
        "-o", output_dir,
        audio_file_path
    ]
    subprocess.run(command, check=True)
    
    song_name = os.path.splitext(os.path.basename(audio_file_path))[0]
    return os.path.join(output_dir, "htdemucs", song_name)


def quantize_time(raw_time, bpm, subdivision=4):
    """
    Ajusta el tiempo exacto a la rejilla rítmica más cercana basada en el BPM.
    """
    seconds_per_beat = 60.0 / bpm
    grid_step = seconds_per_beat / (subdivision / 4.0)
    quantized_step = round(raw_time / grid_step)
    return float(round(quantized_step * grid_step, 4))


def process_stem_to_beatmap(stem_wav_path, instrument, original_wav_name, bpm):
    """
    Procesa el audio aislado de un único instrumento y cuantiza sus notas.
    """
    print(f" -> Analizando stem para: {instrument} ({os.path.basename(stem_wav_path)})...")
    y, sr = librosa.load(stem_wav_path, sr=None)
    duration = float(librosa.get_duration(y=y, sr=sr))

    if instrument == "bateria":
        onset_env = librosa.onset.onset_strength(y=y, sr=sr, aggregate=np.median)
        peaks = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, delta=0.08, wait=4)
        lanes = [0, 1, 2, 3, 4, 5]

    elif instrument == "bajo":
        y_low = librosa.effects.preemphasis(y)
        onset_env = librosa.onset.onset_strength(y=y_low, sr=sr)
        peaks = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, delta=0.12, wait=6)
        lanes = [0, 1, 2]

    elif instrument == "guitarra":
        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        peaks = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, delta=0.09, wait=5)
        lanes = [1, 2, 3, 4]

    else:  # microfono / vocals
        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        peaks = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, delta=0.14, wait=8)
        lanes = [2, 3, 4, 5]

    raw_times = librosa.frames_to_time(peaks, sr=sr)

    notes = []
    seen_times = set()

    for i, t in enumerate(raw_times):
        q_time = quantize_time(t, bpm, subdivision=4)
        
        if q_time not in seen_times and q_time <= duration:
            seen_times.add(q_time)
            selected_lane = lanes[i % len(lanes)]
            notes.append({
                "time": q_time,
                "lane": int(selected_lane)
            })

    notes.sort(key=lambda x: x["time"])

    beatmap_data = {
        "cancion": original_wav_name,
        "bpm_estimado": round(bpm, 2),
        "duration": round(duration, 2),
        "note_count": len(notes),
        "notes": notes
    }

    return beatmap_data


def generate_all_beatmaps(filename):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    audio_path = os.path.join(script_dir, filename)

    if not os.path.exists(audio_path):
        print(f"Error: No se encontró '{filename}' en: {script_dir}")
        return

    # 1. Detectar BPM global
    print("[1/4] Calculando tempo/BPM global de la canción...")
    y_full, sr_full = librosa.load(audio_path, sr=None)
    tempo, _ = librosa.beat.beat_track(y=y_full, sr=sr_full)
    global_bpm = float(np.mean(tempo)) if isinstance(tempo, np.ndarray) else float(tempo)
    print(f" -> BPM detectado: {global_bpm:.2f}")

    # 2. Separar audio con Demucs en la carpeta "stems" local
    stems_output_dir = os.path.join(script_dir, "stems")
    stems_folder = separate_audio_stems(audio_path, stems_output_dir)

    instrument_files = {
        "drums.wav": "bateria",
        "bass.wav": "bajo",
        "other.wav": "guitarra",
        "vocals.wav": "microfono"
    }

    song_basename = os.path.basename(audio_path)
    song_name = os.path.splitext(song_basename)[0]

    print(f"\n[3/4] Buscando pistas generadas en: {stems_folder}")
    
    generated_count = 0
    for wav_file, inst_name in instrument_files.items():
        stem_path = os.path.join(stems_folder, wav_file)
        
        if os.path.exists(stem_path):
            beatmap = process_stem_to_beatmap(stem_path, inst_name, song_basename, global_bpm)
            output_json = os.path.join(script_dir, f"{song_name}_{inst_name}.json")

            with open(output_json, "w", encoding="utf-8") as f:
                json.dump(beatmap, f, indent=2)

            print(f"    [OK] ¡Creado! -> '{os.path.basename(output_json)}' con {beatmap['note_count']} notas.")
            generated_count += 1
        else:
            print(f"    [X] No se encontró el stem: {stem_path}")

    print(f"\n[4/4] ¡Proceso completado! Se generaron {generated_count} archivos .json.")


if __name__ == "__main__":
    SONG_FILE = "ImNotOkay.wav"
    generate_all_beatmaps(SONG_FILE)