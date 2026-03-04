%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Step 09)
%
%  Authors: Peter C.H. Lam & Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    09 - performs manual Independent Component (IC) rejection following ICA decomposition.
%
%  Notes:
%    - Component rejection is applied to the COMPLETE dataset (i.e.,
%      including previously masked segments).
%    - Component selection is interactive.
%
%  ------------------------------------------------------------------------

%% Setup
clear, clc, close all

% Navigate to the root folder of the data
currDir = matlab.desktop.editor.getActive; % Get current active file
currDir = fileparts(currDir.Filename);     % Get its directory
cd(fullfile(currDir, '..'));               % Go up one level

%% Step 09 Remove ICA components

% Select COMPLETE ICA files from 08_ICA/complete
[file_names_complete, file_path_complete] = uigetfile('08_ICA\\complete\\*.set', ...
    'Select COMPLETE ICA Files', 'MultiSelect', 'on');

if isequal(file_names_complete, 0)
    disp('No files selected. Exiting.');
    return;
end

if ischar(file_names_complete)
    file_names_complete = {file_names_complete};
end

masked_folder = fullfile(file_path_complete, '..', 'masked'); % parent folder + masked

for i = 1:numel(file_names_complete)
    complete_name = file_names_complete{i};
    baseName = erase(complete_name, '_complete.set');  % strip suffix
    speakerLabel = baseName(end);
    
    % Build masked filename based on baseName
    masked_name = [baseName, '_masked.set'];
    masked_fullpath = fullfile(masked_folder, masked_name);
    
    if ~isfile(masked_fullpath)
        warning('Masked file not found: %s\nSkipping this dataset.', masked_fullpath);
        continue;
    end
    
    % Load datasets
    EEG_complete = pop_loadset(complete_name, file_path_complete);
    EEG_masked   = pop_loadset(masked_name, masked_folder);
    
    fprintf('Processing file %d/%d: %s\n', i, numel(file_names_complete), complete_name);
    
    ICArem = "N";
    
    while ICArem == "N"
        EEG_masked_labeled = pop_iclabel(EEG_masked, 'default');
        pop_viewprops(EEG_masked_labeled, 0)
        % EEG = EEG_masked_labeled;
        
        componentsRM = input('Which components to remove after manual inspection? (e.g., [1 4 5], or 0 to skip): ');
        
        if isempty(componentsRM) || (isnumeric(componentsRM) && any(componentsRM == 0))
            disp('Skipping component removal for this dataset.');
            ICArem = 'Y'; % accept as-is
            continue;
        end
        
        validComps = 1:size(EEG_masked_labeled.icaweights,1);
        if ~all(ismember(componentsRM, validComps))
            disp('Invalid component selection. Please enter valid component numbers.');
            continue;
        end
        
        EEG_removed = pop_subcomp(EEG_complete, componentsRM, 1); % note: this shows the complete dataset, with the masked segments
        
        ICArem = input('Did you accept the rejection? (Y/N): ', 's');
        ICArem = upper(strtrim(ICArem));
        
        if ICArem == "N"
            disp("Let's try again! Showing labeled ICs once more...");
        else
            EEG_complete = EEG_removed;
        end
    end
    
    % Save cleaned dataset to 09_Pruned folder
    [~, baseNameOut, ~] = fileparts(complete_name);
    
    coreName = erase(baseNameOut, {'_ICA_A_complete', '_ICA_B_complete'});

    finalName = sprintf('%s_pruned_%s.set', coreName, speakerLabel);

    EEG_complete = pop_saveset(EEG_complete, ...
        finalName, '09_Pruned\\');
end
