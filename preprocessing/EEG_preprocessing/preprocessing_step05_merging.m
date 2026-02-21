%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Step 05)
%
%  Authors: Peter C.H. Lam & Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/Hyperscanning-Scripts_Engaging-Conversations-Project/tree/main
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    05 - merges two preprocessed EEG datasets (Subject A and B)
%
%  Notes:
%    - For Dyads 09, 16, and 19, running the file `fixDyads_preprocessingSupplement` 
%      in `util` directory is required before merging to address missing samples (line 94).
%
%  ------------------------------------------------------------------------

%% Setup
clear, clc, close all
% Initiate eeglab
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% Navigate to the root folder of the data
tmp = matlab.desktop.editor.getActive; % Get the current active file
current_dir = fileparts(tmp.Filename); % Get the directory of the current file
up_levels = fullfile(current_dir, '..'); % Go up
eeg_dir = fullfile(up_levels);
cd(fullfile(eeg_dir)); 

% Select files from raw files to be processed
[file_name_A, file_path_A] = uigetfile('04_rmChan//*.set', 'Select subject A (*.set*)', 'MultiSelect', 'off');
[file_name_B, file_path_B] = uigetfile('04_rmChan//*.set', 'Select subject B (*.set*)', 'MultiSelect', 'off');

% Load data
EEG_A = pop_loadset(file_name_A, file_path_A);
EEG_B = pop_loadset(file_name_B, file_path_B);

% Extract the dyad number
num_str = regexp(file_name_A, '\d+', 'match');  % Extract all number sequences
number = sprintf('%02d', str2double(num_str{1})); 
dyad_num = ['hyperEngaging_dyad_' number];


%% Ensure the sync triggers have the same frame distance

% Compare number of Trigger type events
count_EEG_A = sum(strcmp({EEG_A.event.type}, 'T  1'));
count_EEG_B = sum(strcmp({EEG_B.event.type}, 'T  1'));

count_EEG_A == count_EEG_B

%% Rename channels to identify subjects
% Rename EEG_A channel labels
for i = 1:length(EEG_A.chanlocs)
    EEG_A.chanlocs(i).labels = ['A_' EEG_A.chanlocs(i).labels];
end

% Rename EEG_B channel labels
for i = 1:length(EEG_B.chanlocs)
    EEG_B.chanlocs(i).labels = ['B_' EEG_B.chanlocs(i).labels];
end

%% Remove data before the first sync trigger

% Find the FIRST 'Trigger' event in EEG_A and EEG_B
first_trigger_A_index = find(strcmp({EEG_A.event.code}, 'Trigger'), 1, 'first');
first_trigger_A_latency = EEG_A.event(first_trigger_A_index).latency;

first_trigger_B_index = find(strcmp({EEG_B.event.code}, 'Trigger'), 1, 'first');
first_trigger_B_latency = EEG_B.event(first_trigger_B_index).latency;

% Find the LAST 'Trigger' event in EEG_A and EEG_B
last_trigger_A_index = find(strcmp({EEG_A.event.code}, 'Trigger'), 1, 'last');
last_trigger_A_latency = EEG_A.event(last_trigger_A_index).latency;

last_trigger_B_index = find(strcmp({EEG_B.event.code}, 'Trigger'), 1, 'last');
last_trigger_B_latency = EEG_B.event(last_trigger_B_index).latency;

% Remove all data 1 second before and after the first and final trigger
% pulse, respectively
EEG_A = pop_select(EEG_A, 'rmpoint', [0 (first_trigger_A_latency-EEG_A.srate); (last_trigger_A_latency+EEG_A.srate) EEG_A.pnts]);
EEG_B = pop_select(EEG_B, 'rmpoint', [0 (first_trigger_B_latency-EEG_B.srate); (last_trigger_B_latency+EEG_B.srate) EEG_B.pnts]);


%% If needed, fix Data

% If proessing one of the following dyads, please run Preprocessing
% Supplement script.

% - Dyad 09 (Samples lost in A)
% - Dyad 16 (Samples lost in B)
% - Dyad 19 (Samples lost in A due to amp interruption)


run('supplement/fixDyads_preprocessingSupplement.m'); 

%% Rename boundary events to identify subjects
% Find the indices of 'boundary' events
boundary_indices_A = find(strcmp({EEG_A.event.type}, 'boundary'));

% Rename 'boundary' events to 'boundary_A'
for i = 1:length(boundary_indices_A)
    EEG_A.event(boundary_indices_A(i)).type = 'boundary_A'; 
end

%% Save B's removed channels information in any

if ~isempty(EEG_B.chaninfo.removedchans)
    Brm  = EEG_B.chaninfo.removedchans; 
    tnm  = strcat(dyad_num, '_B_rmInfo.mat');
    tpath = convertStringsToChars(fullfile("supplement/Brm/", tnm));
    save(tpath, "Brm")
end

%% Merge datasets

% if the first two events are boundaries:
% EEG_A.event(1:2) = [];
% EEG_A = eeg_checkset(EEG_A);
% EEG_B.event(1:2) = [];
% EEG_B = eeg_checkset(EEG_B);

% EEG_B = eeg_checkset(EEG_B_corrected, 'eventconsistency');
EEG_B = eeg_checkset(EEG_B, 'eventconsistency');
EEG_A = eeg_checkset(EEG_A, 'eventconsistency');

EEG_merged = eeg_mergechannels(EEG_A, EEG_B, 'finalevents', 'merge');

% Check if needed
% pop_eegplot(EEG_merged, 1, 1, 1);

%% Rename renamed boundary events ('boundary_A') back to 'boundary'

% Find the indices of 'boundary_A' events
boundary_A_indices = find(strcmp({EEG_merged.event.type}, 'boundary_A'));

% Rename 'boundary_A' events back to 'boundary'
for i = 1:length(boundary_A_indices)
    EEG_merged.event(boundary_A_indices(i)).type = 'boundary'; 
end

%% Save merged dataset
EEG = pop_editset(EEG_merged, 'setname', strcat(dyad_num, '_merged'));
EEG_merged = pop_saveset(EEG_merged, strcat(dyad_num, '_merged.set'), '05_Merged');
