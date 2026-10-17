[1mdiff --git a/project.godot b/project.godot[m
[1mindex 3e121e2..52584f2 100644[m
[1m--- a/project.godot[m
[1m+++ b/project.godot[m
[36m@@ -31,7 +31,7 @@[m [mwindow/stretch/mode="canvas_items"[m
 [m
 [editor_plugins][m
 [m
[31m-enabled=PackedStringArray("res://addons/AI_Gemini_GD/plugin.cfg", "res://addons/godot-sqlite/plugin.cfg")[m
[32m+[m[32menabled=PackedStringArray("res://addons/godot-sqlite/plugin.cfg")[m
 [m
 [input][m
 [m
[1mdiff --git a/scenes/gameplay.tscn b/scenes/gameplay.tscn[m
[1mindex 46c200f..f28c093 100644[m
[1m--- a/scenes/gameplay.tscn[m
[1m+++ b/scenes/gameplay.tscn[m
[36m@@ -1,7 +1,7 @@[m
 [gd_scene format=3 uid="uid://bpfccrqogeywn"][m
 [m
[31m-[ext_resource type="Script" uid="uid://dq3t30cdxdq7" path="res://scripts/gameplay.gd" id="1_script"][m
[31m-[ext_resource type="Script" uid="uid://x07g0ofh52kb" path="res://scripts/database.gd" id="2_00tan"][m
[32m+[m[32m[ext_resource type="Script" path="res://scripts/gameplay.gd" id="1_script"][m
[32m+[m[32m[ext_resource type="Script" path="res://scripts/database.gd" id="2_00tan"][m
 [ext_resource type="FontFile" uid="uid://du4vnpp518n34" path="res://RhythmicHits.ttf" id="2_l1v76"][m
 [ext_resource type="Shader" uid="uid://vitgrscnpngr" path="res://scenes/kaleidoscopebg.gdshader" id="3_ctvyo"][m
 [ext_resource type="Script" uid="uid://oakew3acqt7m" path="res://scenes/kaleidoscope.gd" id="4_ctvyo"][m
[1mdiff --git a/scenes/note.tscn b/scenes/note.tscn[m
[1mindex c6db521..f715322 100644[m
[1m--- a/scenes/note.tscn[m
[1m+++ b/scenes/note.tscn[m
[36m@@ -22,7 +22,7 @@[m [mscript = ExtResource("1_script")[m
 [m
 [node name="Trail" type="CPUParticles2D" parent="." unique_id=1238011111][m
 amount = 3[m
[31m-lifetime = 0.09999999999999999[m
[32m+[m[32mlifetime = 0.1[m
 emission_shape = 3[m
 emission_rect_extents = Vector2(24, 2)[m
 gravity = Vector2(0, -250)[m
[1mdiff --git a/scenes/song_select.tscn.depren b/scenes/song_select.tscn.depren[m
[1mnew file mode 100644[m
[1mindex 0000000..e609652[m
[1m--- /dev/null[m
[1m+++ b/scenes/song_select.tscn.depren[m
[36m@@ -0,0 +1,335 @@[m
[32m+[m[32m[gd_scene format=3 uid="uid://sy6vpu7m8jgc"][m
[32m+[m
[32m+[m[32m[ext_resource type="Script" uid="uid://c6uirtk2tqm4e" path="res://scripts/song_select.gd" id="1_abcqd"][m
[32m+[m[32m[ext_resource type="Texture2D" uid="uid://swixed2shcs5" path="res://fondito.jpg" id="2_1fack"][m
[32m+[m[32m[ext_resource type="AudioStream" uid="uid://bjs6t600cbndd" path="res://menumusic.wav" id="3_rwalk"][m
[32m+[m[32m[ext_resource type="Texture2D" uid="uid://fle5gifu30c0" path="res://settings.png" id="4_hwm7x"][m
[32m+[m[32m[ext_resource type="FontFile" uid="uid://du4vnpp518n34" path="res://RhythmicHits.ttf" id="5_eq4qm"][m
[32m+[m
[32m+[m[32m[sub_resource type="Environment" id="Environment_rtea6"][m
[32m+[m[32mbackground_mode = 3[m
[32m+[m[32mglow_enabled = true[m
[32m+[m[32mglow_levels/4 = 1.85[m
[32m+[m[32mglow_levels/5 = 1.47[m
[32m+[m[32mglow_levels/6 = 1.75[m
[32m+[m[32mglow_intensity = 4.26[m
[32m+[m[32mglow_blend_mode = 0[m
[32m+[m[32mglow_hdr_threshold = 0.85[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_rtea6"][m
[32m+[m[32mcontent_margin_left = 10.0[m
[32m+[m[32mcontent_margin_top = 10.0[m
[32m+[m[32mcontent_margin_right = 10.0[m
[32m+[m[32mbg_color = Color(0.105882354, 0.31764707, 0.3764706, 0.38431373)[m
[32m+[m[32mborder_width_left = 2[m
[32m+[m[32mborder_width_top = 2[m
[32m+[m[32mborder_width_right = 2[m
[32m+[m[32mborder_width_bottom = 2[m
[32m+[m[32mborder_color = Color(0.111189805, 0.9013767, 0.9752889, 1)[m
[32m+[m[32mcorner_radius_top_right = 40[m
[32m+[m[32mcorner_radius_bottom_left = 40[m
[32m+[m[32mcorner_detail = 1[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_insur"][m
[32m+[m[32mbg_color = Color(0.6, 0.6, 0.6, 0)[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_vakh2"][m
[32m+[m[32mbg_color = Color(0.14117648, 0.14117648, 0.14117648, 0.5372549)[m
[32m+[m[32mborder_width_right = 3[m
[32m+[m[32mborder_width_bottom = 3[m
[32m+[m[32mborder_color = Color(0.85882354, 0, 0.6745098, 1)[m
[32m+[m[32mcorner_radius_top_right = 20[m
[32m+[m[32mcorner_radius_bottom_left = 20[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_a50jo"][m
[32m+[m[32mbg_color = Color(1, 1, 1, 0.39215687)[m
[32m+[m[32mborder_width_left = 3[m
[32m+[m[32mborder_width_top = 3[m
[32m+[m[32mborder_width_right = 3[m
[32m+[m[32mborder_width_bottom = 3[m
[32m+[m[32mborder_color = Color(0.85882354, 0, 0.6745098, 1)[m
[32m+[m[32mcorner_radius_top_right = 20[m
[32m+[m[32mcorner_radius_bottom_left = 20[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_cbght"][m
[32m+[m[32mbg_color = Color(0.14117648, 0.14117648, 0.14117648, 0.5372549)[m
[32m+[m[32mborder_width_left = 3[m
[32m+[m[32mborder_width_top = 3[m
[32m+[m[32mborder_width_right = 3[m
[32m+[m[32mborder_width_bottom = 3[m
[32m+[m[32mborder_color = Color(0.85882354, 0, 0.6745098, 1)[m
[32m+[m[32mcorner_radius_top_right = 20[m
[32m+[m[32mcorner_radius_bottom_left = 20[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_j6d0t"][m
[32m+[m[32mbg_color = Color(0, 0, 0, 0.23921569)[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ibsnk"][m
[32m+[m[32mbg_color = Color(0, 0, 0, 0.23921569)[m
[32m+[m[32mcorner_radius_bottom_left = 40[m
[32m+[m[32mcorner_detail = 1[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_46p8o"][m
[32m+[m[32mbg_color = Color(2.256129e-09, 0.037021313, 0.056692265, 0.6666667)[m
[32m+[m[32mborder_width_left = 2[m
[32m+[m[32mborder_width_top = 2[m
[32m+[m[32mborder_width_right = 2[m
[32m+[m[32mborder_width_bottom = 2[m
[32m+[m[32mborder_color = Color(1, 0, 1, 0)[m
[32m+[m[32mcorner_radius_bottom_right = 30[m
[32m+[m[32mcorner_detail = 1[m
[32m+[m[32mshadow_color = Color(0, 0, 0, 0.31764707)[m
[32m+[m[32mshadow_size = 6[m
[32m+[m[32mshadow_offset = Vector2(7.765, 6.14)[m
[32m+[m
[32m+[m[32m[node name="SongSelect" type="Control" unique_id=1787551014][m
[32m+[m[32mlayout_mode = 3[m
[32m+[m[32manchors_preset = 15[m
[32m+[m[32manchor_right = 1.0[m
[32m+[m[32manchor_bottom = 1.0[m
[32m+[m[32mgrow_horizontal = 2[m
[32m+[m[32mgrow_vertical = 2[m
[32m+[m[32mscript = ExtResource("1_abcqd")[m
[32m+[m
[32m+[m[32m[node name="WorldEnvironment" type="WorldEnvironment" parent="." unique_id=1245086685][m
[32m+[m[32menvironment = SubResource("Environment_rtea6")[m
[32m+[m
[32m+[m[32m[node name="Background" type="ColorRect" parent="." unique_id=1081661548][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_right = 1152.0[m
[32m+[m[32moffset_bottom = 648.0[m
[32m+[m[32mcolor = Color(0.07, 0.07, 0.12, 1)[m
[32m+[m
[32m+[m[32m[node name="Fondito" type="Sprite2D" parent="Background" unique_id=883047082][m
[32m+[m[32mmodulate = Color(1, 1, 1, 0.38039216)[m
[32m+[m[32mposition = Vector2(577.5, 325.22333)[m
[32m+[m[32mscale = Vector2(1.3693588, 1.2515482)[m
[32m+[m[32mtexture = ExtResource("2_1fack")[m
[32m+[m
[32m+[m[32m[node name="HTTPRequest" type="HTTPRequest" parent="." unique_id=1080198715][m
[32m+[m
[32m+[m[32m[node name="BGMPlayer" type="AudioStreamPlayer" parent="." unique_id=1527821194][m
[32m+[m[32mstream = ExtResource("3_rwalk")[m
[32m+[m[32mautoplay = true[m
[32m+[m
[32m+[m[32m[node name="SettingsButton" type="Button" parent="." unique_id=795542271][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 21.999996[m
[32m+[m[32moffset_top = 12.0[m
[32m+[m[32moffset_right = 60.999996[m
[32m+[m[32moffset_bottom = 56.0[m
[32m+[m[32mflat = true[m
[32m+[m
[32m+[m[32m[node name="Settings" type="Sprite2D" parent="." unique_id=1542550562][m
[32m+[m[32mposition = Vector2(40.5, 34)[m
[32m+[m[32mscale = Vector2(0.07617187, 0.078125)[m
[32m+[m[32mtexture = ExtResource("4_hwm7x")[m
[32m+[m
[32m+[m[32m[node name="CyberPanel" type="PanelContainer" parent="." unique_id=548884191][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 260.0[m
[32m+[m[32moffset_top = 24.0[m
[32m+[m[32moffset_right = 890.0[m
[32m+[m[32moffset_bottom = 624.0[m
[32m+[m[32mtheme_override_styles/panel = SubResource("StyleBoxFlat_rtea6")[m
[32m+[m
[32m+[m[32m[node name="VBox" type="VBoxContainer" parent="CyberPanel" unique_id=166184456][m
[32m+[m[32mlayout_mode = 2[m
[32m+[m
[32m+[m[32m[node name="TitleLabel" type="Label" parent="CyberPanel/VBox" unique_id=1207639607][m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_fonts/font = ExtResource("5_eq4qm")[m
[32m+[m[32mtheme_override_font_sizes/font_size = 44[m
[32m+[m[32mtext = "GARAGE BAND"[m
[32m+[m[32mhorizontal_alignment = 1[m
[32m+[m
[32m+[m[32m[node name="SubtitleLabel" type="Label" parent="CyberPanel/VBox" unique_id=262662132][m
[32m+[m[32mmodulate = Color(0.7, 0.7, 0.95, 1)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_fonts/font = ExtResource("5_eq4qm")[m
[32m+[m[32mtheme_override_font_sizes/font_size = 17[m
[32m+[m[32mtext = "Selecciona una cancion"[m
[32m+[m[32mhorizontal_alignment = 1[m
[32m+[m
[32m+[m[32m[node name="Sep1" type="HSeparator" parent="CyberPanel/VBox" unique_id=1431634229][m
[32m+[m[32mcustom_minimum_size = Vector2(0, 16)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m
[32m+[m[32m[node name="SongList" type="ItemList" parent="CyberPanel/VBox" unique_id=1711046916][m
[32m+[m[32mcustom_minimum_size = Vector2(0, 280)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_colors/font_color = Color(0.86010057, 0.965807, 1, 1)[m
[32m+[m[32mtheme_override_colors/font_selected_color = Color(0.99658376, 0.9524483, 0.7431436, 1)[m
[32m+[m[32mtheme_override_font_sizes/font_size = 20[m
[32m+[m[32mtheme_override_styles/panel = SubResource("StyleBoxFlat_insur")[m
[32m+[m
[32m+[m[32m[node name="SongNameLabel" type="Label" parent="CyberPanel/VBox" unique_id=1320941711][m
[32m+[m[32mmodulate = Color(0.95, 0.95, 0.45, 1)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_font_sizes/font_size = 16[m
[32m+[m[32mtext = "Escaneando canciones..."[m
[32m+[m[32mhorizontal_alignment = 1[m
[32m+[m
[32m+[m[32m[node name="Sep2" type="HSeparator" parent="CyberPanel/VBox" unique_id=877343390][m
[32m+[m[32mcustom_minimum_size = Vector2(0, 8)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m
[32m+[m[32m[node name="InstructionsLabel" type="Label" parent="CyberPanel/VBox" unique_id=572169456][m
[32m+[m[32mmodulate = Color(0.55, 0.55, 0.55, 1)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_font_sizes/font_size = 26[m
[32m+[m[32mtext = "Teclas Predeterminadas: D  F  J  K  L"[m
[32m+[m[32mhorizontal_alignment = 1[m
[32m+[m
[32m+[m[32m[node name="Sep3" type="HSeparator" parent="CyberPanel/VBox" unique_id=172687200][m
[32m+[m[32mcustom_minimum_size = Vector2(0, 8)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m
[32m+[m[32m[node name="PlayButton" type="Button" parent="CyberPanel/VBox" unique_id=1673403670][m
[32m+[m[32mcustom_minimum_size = Vector2(0, 58)[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_fonts/font = ExtResource("5_eq4qm")[m
[32m+[m[32mtheme_override_font_sizes/font_size = 30[m
[32m+[m[32mtheme_override_styles/normal = SubResource("StyleBoxFlat_vakh2")[m
[32m+[m[32mtheme_override_styles/pressed = SubResource("StyleBoxFlat_a50jo")[m
[32m+[m[32mtheme_override_styles/hover = SubResource("StyleBoxFlat_cbght")[m
[32m+[m[32mtext = "   JUGAR"[m
[32m+[m
[32m+[m[32m[node name="DownloadButton" type="Button" parent="CyberPanel/VBox" unique_id=1270612682][m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_styles/normal = SubResource("StyleBoxFlat_j6d0t")[m
[32m+[m[32mtext = "BUSCAR CANCIONES"[m
[32m+[m
[32m+[m[32m[node name="TwoPlayerButton" type="Button" parent="CyberPanel/VBox" unique_id=361539423][m
[32m+[m[32mvisible = false[m
[32m+[m[32mlayout_mode = 2[m
[32m+[m[32mtheme_override_styles/normal = SubResource("StyleBoxFlat_ibsnk")[m
[32m+[m[32mtext = "2 Jugadores"[m
[32m+[m
[32m+[m[32m[node name="SettingsPanel" type="Panel" parent="." unique_id=491800494][m
[32m+[m[32mvisible = false[m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 15.0[m
[32m+[m[32moffset_top = 8.0[m
[32m+[m[32moffset_right = 296.0[m
[32m+[m[32moffset_bottom = 409.0[m
[32m+[m[32mtheme_override_styles/panel = SubResource("StyleBoxFlat_46p8o")[m
[32m+[m
[32m+[m[32m[node name="HSlider" type="HSlider" parent="SettingsPanel" unique_id=208536802][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 10.0[m
[32m+[m[32moffset_top = 113.0[m
[32m+[m[32moffset_right = 231.0[m
[32m+[m[32moffset_bottom = 157.0[m
[32m+[m[32mmin_value = 0.001[m
[32m+[m[32mmax_value = 1.0[m
[32m+[m[32mstep = 0.01[m
[32m+[m[32mvalue = 0.401[m
[32m+[m
[32m+[m[32m[node name="ModoDaltonimsoSwitch" type="CheckButton" parent="SettingsPanel" unique_id=1262813196][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 10.0[m
[32m+[m[32moffset_top = 155.0[m
[32m+[m[32moffset_right = 54.0[m
[32m+[m[32moffset_bottom = 201.0[m
[32m+[m
[32m+[m[32m[node name="LabelDaltonismo" type="Label" parent="SettingsPanel" unique_id=1217692168][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 52.0[m
[32m+[m[32moffset_top = 166.0[m
[32m+[m[32moffset_right = 212.0[m
[32m+[m[32moffset_bottom = 189.0[m
[32m+[m[32mtext = "Modo Daltonismo"[m
[32m+[m
[32m+[m[32m[node name="EnglishSwitch" type="CheckButton" parent="SettingsPanel" unique_id=1049719954][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 11.0[m
[32m+[m[32moffset_top = 185.0[m
[32m+[m[32moffset_right = 55.0[m
[32m+[m[32moffset_bottom = 231.0[m
[32m+[m
[32m+[m[32m[node name="LabelEnglish" type="Label" parent="SettingsPanel" unique_id=14985470][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 54.0[m
[32m+[m[32moffset_top = 196.0[m
[32m+[m[32moffset_right = 214.0[m
[32m+[m[32moffset_bottom = 245.0[m
[32m+[m[32mtext = "English[m
[32m+[m[32m"[m
[32m+[m
[32m+[m[32m[node name="LabelVolumen" type="Label" parent="SettingsPanel" unique_id=82190167][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 10.0[m
[32m+[m[32moffset_top = 88.0[m
[32m+[m[32moffset_right = 228.0[m
[32m+[m[32moffset_bottom = 114.0[m
[32m+[m[32mtext = "Volumen"[m
[32m+[m
[32m+[m[32m[node name="LabelTeclas" type="Label" parent="SettingsPanel" unique_id=1147293638][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 12.0[m
[32m+[m[32moffset_top = 228.0[m
[32m+[m[32moffset_right = 60.0[m
[32m+[m[32moffset_bottom = 251.0[m
[32m+[m[32mtext = "Teclas"[m
[32m+[m
[32m+[m[32m[node name="BtnCarril1" type="Button" parent="SettingsPanel" unique_id=1600186294][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 7.0[m
[32m+[m[32moffset_top = 257.0[m
[32m+[m[32moffset_right = 88.0[m
[32m+[m[32moffset_bottom = 288.0[m
[32m+[m[32mtext = "Carril 1: S"[m
[32m+[m
[32m+[m[32m[node name="BtnCarril2" type="Button" parent="SettingsPanel" unique_id=1582983859][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 123.0[m
[32m+[m[32moffset_top = 256.0[m
[32m+[m[32moffset_right = 204.0[m
[32m+[m[32moffset_bottom = 287.0[m
[32m+[m[32mtext = "Carril 2: D"[m
[32m+[m
[32m+[m[32m[node name="BtnCarril3" type="Button" parent="SettingsPanel" unique_id=634800124][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 14.0[m
[32m+[m[32moffset_top = 305.0[m
[32m+[m[32moffset_right = 95.0[m
[32m+[m[32moffset_bottom = 336.0[m
[32m+[m[32mtext = "Carril 3: F"[m
[32m+[m
[32m+[m[32m[node name="BtnCarril4" type="Button" parent="SettingsPanel" unique_id=1362650500][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 127.0[m
[32m+[m[32moffset_top = 305.0[m
[32m+[m[32moffset_right = 208.0[m
[32m+[m[32moffset_bottom = 336.0[m
[32m+[m[32mtext = "Carril 4: H"[m
[32m+[m
[32m+[m[32m[node name="BtnCarril5" type="Button" parent="SettingsPanel" unique_id=2083978426][m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 16.0[m
[32m+[m[32moffset_top = 352.0[m
[32m+[m[32moffset_right = 97.0[m
[32m+[m[32moffset_bottom = 383.0[m
[32m+[m[32mtext = "Carril 5: J"[m
[32m+[m
[32m+[m[32m[node name="SettingsCerrar" type="Button" parent="." unique_id=399447538][m
[32m+[m[32mvisible = false[m
[32m+[m[32mlayout_mode = 0[m
[32m+[m[32moffset_left = 225.0[m
[32m+[m[32moffset_top = 20.0[m
[32m+[m[32moffset_right = 283.0[m
[32m+[m[32moffset_bottom = 51.0[m
[32m+[m[32mtheme_override_fonts/font = ExtResource("5_eq4qm")[m
[32m+[m[32mtext = "Cerrar"[m
[32m+[m
[32m+[m[32m[connection signal="pressed" from="SettingsButton" to="." method="_on_settings_button_pressed"][m
[32m+[m[32m[connection signal="value_changed" from="SettingsPanel/HSlider" to="." method="_on_h_slider_value_changed"][m
[32m+[m[32m[connection signal="toggled" from="SettingsPanel/ModoDaltonimsoSwitch" to="." method="_on_check_button_toggled"][m
[32m+[m[32m[connection signal="toggled" from="SettingsPanel/EnglishSwitch" to="." method="_on_english_switch_toggled"][m
[32m+[m[32m[connection signal="pressed" from="SettingsPanel/BtnCarril1" to="." method="_on_btn_carril_1_pressed"][m
[32m+[m[32m[connection signal="pressed" from="SettingsPanel/BtnCarril2" to="." method="_on_btn_carril_2_pressed"][m
[32m+[m[32m[connection signal="pressed" from="SettingsPanel/BtnCarril3" to="." method="_on_btn_carril_3_pressed"][m
[32m+[m[32m[connection signal="pressed" from="SettingsPanel/BtnCarril4" to="." method="_on_btn_carril_4_pressed"][m
[32m+[m[32m[connection signal="pressed" from="SettingsPanel/BtnCarril5" to="." method="_on_btn_carril_5_pressed"][m
[32m+[m[32m[connection signal="pressed" from="SettingsCerrar" to="." method="_on_settings_cerrar_pressed"][m
[1mdiff --git a/scenes/song_select.tscn85186111.tmp b/scenes/song_select.tscn85186111.tmp[m
[1mnew file mode 100644[m
[1mindex 0000000..afecaf5[m
[1m--- /dev/null[m
[1m+++ b/scenes/song_select.tscn85186111.tmp[m
[36m@@ -0,0 +1,335 @@[m
[32m+[m[32m[gd_scene format=3 uid="uid://sy6vpu7m8jgc"][m
[32m+[m
[32m+[m[32m[ext_resource type="Script" path="res://scripts/song_select.gd" id="1_abcqd"][m
[32m+[m[32m[ext_resource type="Texture2D" uid="uid://swixed2shcs5" path="res://fondito.jpg" id="2_1fack"][m
[32m+[m[32m[ext_resource type="AudioStream" uid="uid://bjs6t600cbndd" path="res://menumusic.wav" id="3_rwalk"][m
[32m+[m[32m[ext_resource type="Texture2D" uid="uid://fle5gifu30c0" path="res://settings.png" id="4_hwm7x"][m
[32m+[m[32m[ext_resource type="FontFile" uid="uid://du4vnpp518n34" path="res://RhythmicHits.ttf" id="5_eq4qm"][m
[32m+[m
[32m+[m[32m[sub_resource type="Environment" id="Environment_rtea6"][m
[32m+[m[32mbackground_mode = 3[m
[32m+[m[32mglow_enabled = true[m
[32m+[m[32mglow_levels/4 = 1.85[m
[32m+[m[32mglow_levels/5 = 1.47[m
[32m+[m[32mglow_levels/6 = 1.75[m
[32m+[m[32mglow_intensity = 4.26[m
[32m+[m[32mglow_blend_mode = 0[m
[32m+[m[32mglow_hdr_threshold = 0.85[m
[32m+[m
[32m+[m[32m[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_rtea6"][m
[32m+[m[32mcontent_margin_left = 10.0[m
[32m+[m[32mcontent_margin_top = 10.0[m
[32m+[m[32mcontent_margin_right = 10.0[m
[32m+[m[32mbg_color = Color(0.105882354, 0.31764707, 0.3764706, 0.38431373)[m
[32m+[m[32mborder_width_left = 2[m
[32m+[m[32mborder_width_top = 2[m
[32m+[m[32mborder_width_right = 2[m
[32m+[m[32mborder_width_bottom = 2[m
[32m+[m[32mborder_color = Color(0.111189805, 0.9013767, 0.9752889, 1)[m
[32m+[m[32mcorner_radius_top_right = 40[m
[32m+[m[32mco