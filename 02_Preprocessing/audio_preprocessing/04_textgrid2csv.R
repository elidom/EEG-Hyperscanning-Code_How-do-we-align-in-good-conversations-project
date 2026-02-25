# -------------------------------------------------------------------------
#  AUDIO PREPROCESSING PIPELINE (Step 04)
#  Clean TextGrid → Structured Spreadsheet
#
#  Author: Marcos E. Domínguez Arriola & Peter C.H. Lam
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
#           How Do We Align in Good Conversation?
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#
#  Converts manually cleaned Praat TextGrid files into structured spreadsheets.
#
#  Notes:
#      - Assumes cleaned TextGrids with tiers "A" and "B"
#      - Outputs CSV files for downstream alignment with EEG
# -------------------------------------------------------------------------

currentDyad = "Dyad28" # set dyad

library(phonfieldwork)
library(tidyverse)
library(xlsx)

script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
base_dir <- file.path(script_dir, "..", "..") # Go up two levels
audio_dir <- file.path(base_dir, "Audio")

# Check if the target audio directory exists
if (!dir.exists(audio_dir)) {
  stop(paste("Audio directory not found at:", audio_dir))
}
setwd(audio_dir)
print(paste("Current working directory set to:", getwd()))

input_folder <- file.path("05_clean_textGrid", currentDyad)
other_folder <- file.path("DaphneLogistics/Step 2 Clean textgrid/Output", currentDyad)
output_folder_csv <- file.path("06_as_csv", currentDyad)

if (!dir.exists(input_folder)) {
  dir.create(input_folder, recursive = TRUE)
  files <- list.files(other_folder, full.names = TRUE)
  file.copy(files, input_folder, overwrite = TRUE)
}

if (!dir.exists(output_folder_csv)) {
  dir.create(output_folder_csv, recursive = TRUE)
}

# Get all file names from the input folder
tg_files <- list.files(path = input_folder, full.names = TRUE) 

for (file in tg_files) {

  df <- textgrid_to_df(file) 
  
  df2 <- df %>% select(time_start, tier_name, content, time_end) %>% 
    rename(tmin = time_start,
           tmax = time_end,
           text = content,
           tier = tier_name) %>%
    
    mutate(tier = factor(tier, levels = c("A", "B"), labels = c("SpeakerA", "SpeakerB"))) %>%
    filter(text != "")
  
  csvname = paste0(file.path(output_folder_csv, tools::file_path_sans_ext(basename(file))), ".xlsx")
    
  write.xlsx(df2, csvname, row.names = FALSE)
}

