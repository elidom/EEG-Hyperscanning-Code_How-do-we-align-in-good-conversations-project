# Hyperscanning-Scripts_Engaging-Conversations-Project

This repository contains all the code used for data collection, preprocessing, neural speech tracking and neural coordination estimation (processing), and statistical analysis in the manuscript "How Do We Align in Good Conversation? Investigating the Link Between Interaction Quality and Multimodal Interpersonal Coordination" (under review).
Preprocessed data will be made available upon acceptance of the manuscript for publication.

`01_Experiment` contains the MATLAB script used to run the experiment in an EEG hyperscanning setup, using the [Psychophysics Toolbox Version 3 (PTB-3)](http://psychtoolbox.org/).

`02_Preprocessing` contains the EEG and audio preprocessing pipelines. 
The EEG preprocessing pipeline includes several user-guided steps, such as visual quality control, selection of channels for interpolation, and manual masking of gross artifacts.
The audio preprocessing pipeline also requires two manual steps: speaker diarization and quality control of the generated TextGrid files. These manual interventions were necessary because only a single microphone was used to record both speakers, which made automatic speaker separation difficult, especially during overlapping speech. As a result, diarization and correction can be time-consuming. For future data collection, we strongly recommend using two separate microphones (one per speaker) to substantially improve pipeline efficiency.

`03_Processing` contains the workflows to estimate the brain-to-speech (neural speech tracking) and brain-to-brain (inter-brain relationships) [gaussian copula mutual information (GCMI)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5324576/) between interlocutors from the preprocessed data. Because these analyses are computationally intensive, they are implemented using the [Parallel Computing Toolbox](https://www.mathworks.com/products/parallel-computing.html). Note that all functions contained in the `util` subfolder must be added to the MATLAB path before running the processing scripts.

`04_Analysis` contains the code (in R and R Markdown) used for data wrangling, visualization, and statistical analysis with [lme4](https://cran.r-project.org/web/packages/lme4/lme4.pdf). 
