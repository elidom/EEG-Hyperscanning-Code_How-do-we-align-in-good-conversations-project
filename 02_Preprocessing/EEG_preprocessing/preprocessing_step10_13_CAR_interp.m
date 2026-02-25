%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Steps 10-13)
%
%  Authors: Peter C.H. Lam & Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/Hyperscanning-Scripts_Engaging-Conversations-Project/tree/main
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    10 - Interpolate previously removed channels.
%    11 - Re-reference to common average (CAR) after restoring FCz.
%    12 - Generate event list using ERPLAB.
%    13 - Apply REST reference transformation.
%
%  Notes:
%    - Channel interpolation uses stored removal logs.
%    - Dyad 18 contains manual event code corrections.
%
%  ------------------------------------------------------------------------

%% Setup
clear, clc, close all

% Navigate to the root folder of the data
currDir = matlab.desktop.editor.getActive; % Get current active file
currDir = fileparts(currDir.Filename);     % Get its directory
cd(fullfile(currDir, '..'));               % Go up one level

% Select file to be processed
[file_names, file_path] = uigetfile('09_Pruned\\*.set',  'set Files (*.set*)','MultiSelect','on');

for i = 1:numel(file_names)

    file_name = file_names{i};
    [~, filename_strip, ~] = fileparts(file_name);
    spkrLabel = filename_strip(end);
    coreName = erase(filename_strip, {'_pruned_A', '_pruned_B'});

    % Extract sub ID
    subID = regexprep(file_name, 'hyperEngaging_|_pruned|.set', '');
    
    % Load file
    EEG = pop_loadset(file_name, file_path);
    
    %% Step 10 Interpolation
    if contains(subID, '_A')
        if isfield(EEG.chaninfo, 'removedchans')
            
            excludePattern = '^(A_|B_)|aux';
    
            excludeMask = cellfun(@(x) ~isempty(regexp(x, excludePattern, 'ignorecase')), {EEG.chaninfo.removedchans.labels});
    
            % Keep channels NOT matching the pattern
            interp_chans = EEG.chaninfo.removedchans(~excludeMask);
    
            EEG = pop_interp(EEG, interp_chans, 'spherical');
            
        end
    
    elseif contains(subID, '_B')
        
        pattern2look4 = ['*' subID '*'];
        files = dir(fullfile('supplement/Brm', pattern2look4));

        if ~isempty(files)
            
            interp_chans = load(fullfile(files.folder, files.name)).Brm;
            EEG = pop_interp(EEG, interp_chans, 'spherical');

        end
    else
        error('Something went wrong.');
    end
    
    % Save data 
    EEG = pop_editset(EEG, 'setname', strcat(coreName, '_interp_', spkrLabel));
    EEG = pop_saveset(EEG, strcat(coreName, '_interp_', spkrLabel, '.set'), '10_Interpolation\\');
    
    %% Step 11 CAR

    % Get all channel labels
    labels = {EEG.chanlocs.labels};
    % Index aux channel if exist
    auxIdx = find(contains(labels, 'aux', 'IgnoreCase', true));
    
    EEG = pop_chanedit(EEG, ...
        'append', length(EEG.chanlocs), ...
        'changefield', {length(EEG.chanlocs) + 1, 'labels', 'FCz'}, ...
        'lookup', 'C:\\Program Files\\eeglab2025.0.0\\plugins\\dipfit\\standard_BEM\\elec\\standard_1005.elc', ...
        'setref', {strcat('1:', num2str(length(EEG.chanlocs))), 'FCz'} ...
        );

    % Re-reference from FCz to average
    EEG = pop_reref(EEG, [], ...
    'exclude', auxIdx, ...      % <-- SUPER IMPORTANT THAT THIS IS OUTSIDE STRUCT!!
    'refloc', struct( ...
        'labels', {'FCz'}, 'type', {''}, 'theta', {0.7867}, 'radius', {0.095376}, ...
        'X', {27.39}, 'Y', {-0.3761}, 'Z', {88.668}, ...
        'sph_theta', {-0.7867}, 'sph_phi', {72.8323}, 'sph_radius', {92.8028}, ...
        'urchan', {66}, 'ref', {''}, 'datachan', {0}));

    % Save data
    EEG = pop_editset(EEG, 'setname', strcat(coreName, '_CAR', spkrLabel));
    EEG = pop_saveset(EEG, strcat(coreName, '_CAR_', spkrLabel, '.set'), '11_CAR\\');

    %% Special case: Dyad 18 requires some fixing:

    if contains(subID, 'dyad_18')
        % Remove 'S 31' and 'S 41'
        EEG.event(ismember({EEG.event.type}, {'S 31','S 41'})) = [];
        
        % Change 'S 37' -> 'S 31'
        idx37 = find(strcmp({EEG.event.type}, 'S 37'));
        EEG.event(idx37).type = 'S 31';
        % Change 'S 47' -> 'S 41'
        idx47 = find(strcmp({EEG.event.type}, 'S 47'));
        EEG.event(idx47).type = 'S 41';
         
        EEG = eeg_checkset(EEG);
    end

    %% Step 12 Event List

    EEG  = pop_editeventlist( EEG , ...
        'AlphanumericCleaning', 'on', ...
        'BoundaryNumeric', { -99}, ...
        'BoundaryString', { 'boundary' }, ...
        'List', '12_EventList\event_codes_hyperEngaging_v2.txt', ...
        'SendEL2', 'EEG', ...
        'UpdateEEG', 'code', ...
        'Warning', 'off'); 

    % Save data
    EEG = pop_editset(EEG, 'setname', strcat(coreName, '_elist_', spkrLabel));
    EEG = pop_saveset(EEG, strcat(coreName, '_elist_', spkrLabel, '.set'), '12_EventList\\');
    
    %% Step 13 REST
    
    if spkrLabel == 'A'
        % Find aux channel indices (case-insensitive)
        auxIdx = find(contains({EEG.chanlocs.labels}, 'aux', 'IgnoreCase', true));
        
        if ~isempty(auxIdx)
            % Remove aux channels
            EEG_noAux = pop_select(EEG, 'nochannel', auxIdx);
            X      = double(eeg_getdatact(EEG_noAux))';      % time × channels
            
            % Run ref_infinity on EEG_noAux using all its channels
            EEG_noAux = ref_infinity(EEG_noAux, 'chanlist', 1:length(EEG_noAux.chanlocs));
            
            % Extract aux channels from original EEG
            EEG_aux = pop_select(EEG, 'channel', {'Aux1'});
               
            % Save dataset with only aux channel
            EEG_aux = pop_editset(EEG_aux, 'setname', strcat(coreName, '_auxONLY_', spkrLabel));
            EEG_aux = pop_saveset(EEG_aux, strcat(coreName, '_auxONLY_', spkrLabel, '.set'), '13a_auxONLY\\');
            
        else
            warning('No aux channels found for removal.');
            % Just run ref_infinity normally
            EEG = ref_infinity(EEG, 'chanlist', 1:length(EEG.chanlocs));
        end

    else
        EEG_noAux = ref_infinity(EEG, 'chanlist', 1:33);
    
    end

    X      = double(eeg_getdatact(EEG_noAux))';      % time × channels
    aux    = double(eeg_getdatact(EEG_aux))';
    r0      = max(abs(corr(X, aux)));   

    disp(['# --------------- ' subID ' ~ ' 'r0 = ' num2str(r0) ' --------------- #'])

    % Save data
    EEG_noAux = pop_editset(EEG_noAux, 'setname', strcat(coreName, '_REST_', spkrLabel));
    EEG_noAux = pop_saveset(EEG_noAux, strcat(coreName, '_REST_', spkrLabel, '.set'), '13_REST\\');

end

 