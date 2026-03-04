# -------------------------------------------------------------------------
#  CONTROL ANALYSIS - Surrogate Datasets Preparation
#
#  Author: Marcos E. Domínguez Arriola
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
#           How Do We Align in Good Conversation?
#
#  DESCRIPTION:
#      Integrates surrogate (shuffled-dyad) neural datasets with
#      behavioral conversation measures. Produces analysis-ready
#      datasets for permutation.
#
#  Notes:
#    - The user needs to manually specify frequency band and temporal dependency.
#    
# -------------------------------------------------------------------------

library(tidyverse)
library(here)

frequency_band    <- "alpha"
temporal_dep      <- "recurrent"
surrogate_samples <- 1:200


# load and tidy convo data
convo_data <- readRDS(here("data", "1_behavioral_data", "conversation_scores_tidy.RDS")) %>% 
  rename(Dyad = dyad,
         Type = interest) %>% 
  mutate(Dyad = str_replace(Dyad, "^D", "Dyad"),
         Type = ifelse(Type == "low", "LowInterest", "HighInterest"),
         log_bid = pmax(log_bid, 0)) %>% 
  group_by(Dyad, id) %>% 
  mutate(sbid = as.numeric(scale(log_bid))) %>% 
  ungroup()

convo_data$Type[is.na(convo_data$Type)] = "HighInterest"
convo_data$block[is.na(convo_data$block)] = 6


t1 <- Sys.time()

for (i in surrogate_samples) {
  
  if (!(frequency_band %in% c("alpha", "theta"))) {
    print("frequency band has to be 'alpha' or 'theta'")
    break
  }
  
  if (temporal_dep == "concurrent") {
    lagmi_shuffled <- read_csv(
      paste0("../6_postprocessing/output/10b_shuffled_dyads/gcmi_sync_shuffled_surrogates_", as.character(i), ".csv")
    )
  } else if (temporal_dep == "recurrent") {
    lagmi_shuffled <- read_csv(
      paste0("../6_postprocessing/output/10b_shuffled_dyads/gcmi_rcrr_shuffled_surrogates_",
             frequency_band, "_", as.character(i), ".csv")
    )
  } else {
    print("Invalid.")
    break
  }
  
  
  lagmi_shuffled2 <- lagmi_shuffled %>% 
    filter(FrequencyBand == frequency_band) %>%  
    separate(Trial, into = c("Type", "Speaker", "block"), sep = "_") %>% 
    filter(Type %in% c("HighInterest", "LowInterest"))
    
  lagmi_shuffled3 <- lagmi_shuffled2 %>% 
    mutate(Type = factor(Type),
           Speaker = factor(Speaker),
           block = as.numeric(block),
           across(Channel_A:Channel_B, factor),
           FrequencyBand = factor(FrequencyBand)) %>% 
    rename(Band = FrequencyBand) %>% 
    separate(Subject_A, into = c("DyadA", NA)) %>% 
    separate(Subject_B, into = c("DyadB", NA)) %>% 
    mutate(across(DyadA:DyadB, factor))
  
  convo_data_wide <- 
    convo_data %>% 
    select(-person_id) %>% 
    pivot_wider(
      id_cols   = c(Dyad, block, conversation_number, conv_topic_clean, Type),
      names_from  = id,                       # A / B become column suffixes
      values_from = c(conv_interest:sbid),    # all measures to widen
      names_glue  = "{.value}_{id}"           # e.g., conv_interest_A, sbid_B
    ) %>% 
    select(Dyad, Type, block, engagement_PC1_A, engagement_PC1_B) %>% 
    rename(PIQ_A = engagement_PC1_A, 
           PIQ_B = engagement_PC1_B) %>% 
    mutate(Dyad = factor(Dyad),
           Type = factor(Type))
  
  shuffled_with_PIQ <- lagmi_shuffled3 %>%
    left_join(convo_data_wide,
              by = c(
                "DyadA" = "Dyad",
                "Type"  = "Type",
                "block" = "block"
              )) %>%
    select(-PIQ_B) %>%
    left_join(
      convo_data_wide %>% select(-PIQ_A),
      by = c(
        "DyadB" = "Dyad",
        "Type"  = "Type",
        "block" = "block"
      )
    ) %>% 
    mutate(PIQ_mean = (PIQ_A + PIQ_B)/2)
  
  if (temporal_dep == "concurrent") {
    saveRDS(shuffled_with_PIQ, here("data", "9b_shuffled_surrogates_sync", paste0("Shuffled_GCMI_", str_to_title(frequency_band) ,"_", as.character(i), ".RDS")))
    
  } else if (temporal_dep == "recurrent") {
    saveRDS(shuffled_with_PIQ, here("data", "9b_shuffled_surrogates_rcrr", paste0("Shuffled_GCMI_", str_to_title(frequency_band) ,"_", as.character(i), ".RDS"))) 
    }

  t2 <- Sys.time()
  print(t2-t1)
  
}
