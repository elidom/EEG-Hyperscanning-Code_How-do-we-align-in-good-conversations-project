clear, clc, close all
% Initiate eeglab
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% Navigate to the root folder of the data
tmp = matlab.desktop.editor.getActive; % Get the current active file
current_dir = fileparts(tmp.Filename); % Get the directory of the current file
up_one_level = fullfile(current_dir, '..');
eeg_dir = fullfile(up_one_level);
cd(fullfile(eeg_dir));

filename1 = 'hyperEngaging_A_000019.vhdr';
filename2 = 'hyperEngaging_A_000019_cont.vhdr';
filename_strip = 'hyperEngaging_A_000019';

EEG1 = pop_loadbv('00_Raw\\', filename1, []);
EEG2 = pop_loadbv('00_Raw\\', filename2, []);

EEG = pop_mergeset(EEG1, EEG2, 0);
