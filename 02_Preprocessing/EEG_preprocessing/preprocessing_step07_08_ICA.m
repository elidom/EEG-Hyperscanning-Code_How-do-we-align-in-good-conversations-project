%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Steps 07-08)
%
%  Authors: Peter C.H. Lam & Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/Hyperscanning-Scripts_Engaging-Conversations-Project/tree/main
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    07 - Splits the merged dataset into Subject A and Subject B
%    08 - Runs Independent Component Analysis (ICA) separately for each
%    participant.
%
%  Notes:
%    - ICA is computed on masked data (artifact segments removed), but ICA weights are copied 
%      back to the full continuous dataset.
%    - Masked intervals must already be stored in EEG.maskedIntervals.
%    - Auxiliary (StimTrack) channel excluded from ICA.
%    - Manual masking intervals are stored within the EEG structure.
%
%  ------------------------------------------------------------------------

%% Setup
clear, clc, close all

% Navigate to the root folder of the data
currDir = matlab.desktop.editor.getActive; % Get current active file
currDir = fileparts(currDir.Filename);     % Get its directory
cd(fullfile(currDir, '..'));               % Go up one level

% Select file to be processed
[file_name, file_path] = uigetfile('06_MR\\*.set',  'set Files (*.set*)','MultiSelect','off');

% Extract dyad ID
dyadID = regexprep(file_name, 'hyperEngaging_|_MR.*', '');

% Load file
EEG = pop_loadset(file_name, file_path);

%% Step 07 Split into A and B datasets
prefixes = {'A_', 'B_'};   % channel label prefixes
labels   = {'A', 'B'};     % for filenames
EEG_parts = cell(1, numel(prefixes));

for p = 1:numel(prefixes)
    
    % Find channels with the current prefix
    whichCh = find(startsWith({EEG.chanlocs.labels}, prefixes{p}));
    
    % Select only those channels
    EEG_part = pop_select(EEG, 'channel', whichCh);
    
    % Remove prefix from channel labels
    for i = 1:length(EEG_part.chanlocs)
        EEG_part.chanlocs(i).labels = EEG_part.chanlocs(i).labels(length(prefixes{p})+1:end);
    end
    
    % Save to 07_MR_Fix
    EEG_part = pop_saveset(EEG_part, ...
        sprintf('hyperEngaging_%s_MR_%s.set', dyadID, labels{p}), '07_MR_Fix\\');
    
    EEG_parts{p} = EEG_part; % store for next step
end

%% Step 08 Run ICA for both datasets and save masked + complete versions
for p = 1:numel(EEG_parts)
    
    EEG_part = EEG_parts{p};
    
    % Reject masked intervals if present
    if isfield(EEG_part, 'maskedIntervals') && ~isempty(EEG_part.maskedIntervals)
        rejIntervalsSamples = round(EEG_part.maskedIntervals);
        EEG_part_ica = eeg_eegrej(EEG_part, rejIntervalsSamples);
    else
        EEG_part_ica = EEG_part;
    end

    chlabels  = {EEG_part_ica.chanlocs.labels};
    isAux = contains(chlabels, 'Aux', 'IgnoreCase', true);
    nchans = sum(~isAux); 

    % Run ICA on masked data
    EEG_part_ica = pop_runica(EEG_part_ica, 'icatype', 'runica', ...
        'chanind', 1:nchans, 'extended', 1, 'rndreset','yes', 'interrupt','on');
    
    % Copy ICA results back to original full dataset
    EEG_part.icaweights   = EEG_part_ica.icaweights;
    EEG_part.icasphere    = EEG_part_ica.icasphere;
    EEG_part.icawinv      = EEG_part_ica.icawinv;
    EEG_part.icachansind  = EEG_part_ica.icachansind;
    
    % Save masked dataset with ICA weights to 08_ICA/masked
    EEG_part_ica = pop_editset(EEG_part_ica, 'setname', ...
        sprintf('hyperEngaging_%s_ICA_%s_masked', dyadID, labels{p}));
    EEG_part_ica = pop_saveset(EEG_part_ica, ...
        sprintf('hyperEngaging_%s_ICA_%s_masked.set', dyadID, labels{p}), '08_ICA\\masked\\');
    
    % Save full dataset with ICA weights to 08_ICA/complete (this will be used later)
    EEG_part = pop_editset(EEG_part, 'setname', ...
        sprintf('hyperEngaging_%s_ICA_%s_complete', dyadID, labels{p}));
    EEG_part = pop_saveset(EEG_part, ...
        sprintf('hyperEngaging_%s_ICA_%s_complete.set', dyadID, labels{p}), '08_ICA\\complete\\');
    
    % Update storage for any further use
    EEG_parts{p} = EEG_part;
end
