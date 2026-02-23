# -------------------------------------------------------------------------
#  STEP 01: BRAIN-TO-BRAIN DATA WRANGLING 
#
#  Authors: Marcos E. Domínguez-Arriola & Peter C.H. Lam
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
#           How Do We Align in Good Conversation?
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#
#  Tidies and merges brain-to-brain GCMI results with behavioral
#  conversation measures.
#
# -------------------------------------------------------------------------

#  - - - - - - - - - - - Prep
library(tidyverse)
library(here)

inputDir <- "../6_postprocessing/output/11_gcmi_quick"

eeg_labels <- c(
  "Fp1", "Fz", "F3", "F7", "FT9", "FC5", "FC1", "C3", "T7", "TP9",
  "CP5", "CP1", "Pz", "P3", "P7", "O1", "Oz", "O2", "P4", "P8",
  "TP10", "CP6", "CP2", "Cz", "C4", "T8", "FT10", "FC6", "FC2", "F4",
  "F8", "Fp2", "FCz"
)

edge_labels <- read_csv("pairs_edges.csv") %>% 
  select(pair_from, A_from, B_from) %>% 
  arrange(pair_from) %>% 
  distinct() %>% 
  mutate(edge = paste0(A_from, "__", B_from)) %>%
  pull(edge) |> append(c("Fp2__Fp2", "Fp2__FCz", "FCz__Fp2", "FCz__FCz"))

# - - - - - - - - - - - - Convo Data
convo_data <- 
  readRDS(here("data", "1_behavioral_data", "conversation_scores_very_tidy.RDS")) %>% 
  select(-person_id) %>% 
  pivot_wider(
    id_cols   = c(Dyad, Block, conversation_number, conv_topic_clean, Type),
    names_from  = id,                       # A / B become  suffixes
    values_from = c(conv_interest:PIQ),    #  measures to widen
    names_glue  = "{.value}_{id}"           # e.g., conv_interest_A, sbid_B
  )

# - - - - - - - - - - - - GCMI Data
gcmi <- read_csv(file.path(inputDir, "brain2brain_gcmi.csv"))

# # sanity check that bias correction worked:
# gcmi %>% 
#   filter(Channel_A == "Fp1" & Channel_B == "Fp1") %>% 
#   ggplot(aes(x=EffectiveLength, y = SyncMI)) + 
#   geom_point(alpha = .2) +
#   geom_smooth() 

gcmi2 <- gcmi %>% 
  separate(Trial, into = c("Type", "Speaker", "Num"), sep = "_", remove = F) %>% 
  mutate(across(c(Trial, Type, Speaker, Channel_A, Channel_B, FrequencyBand, Dyad), factor)) %>% 
  rename(Block = Num)

gcmi3 <- gcmi2 %>% 
  mutate(
    Channel_A = factor(Channel_A, levels = eeg_labels),
    Channel_B = factor(Channel_B, levels = eeg_labels),
    electrode_pair = paste0(Channel_A, "__", Channel_B),
    electrode_pair = factor(electrode_pair, levels = edge_labels),
    Block = as.numeric(Block)
  )


# - - - - - - - - - - - - - Join Data

gcmi_convo_df <- 
  gcmi3 %>% 
  left_join(convo_data) %>%
  mutate(sharedPIQ = (PIQ_A + PIQ_B)/2)


# saveRDS(gcmi_convo_df, here("data", "brain2brain_gcmi_piq_df.rds"))


