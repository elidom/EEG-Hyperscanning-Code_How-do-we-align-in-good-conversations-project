%% ------------------------------------------------------------------------
%  EEG PREPROCESSING PIPELINE (Steps 00–04)
%
%  Authors: Peter C.H. Lam & Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/Hyperscanning-Scripts_Engaging-Conversations-Project/tree/main
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review) How Do We Align in Good Conversation?
% 
%  EEG Preprocessing steps:
%    00 - Load raw BrainVision files (.vhdr)
%    01 - Convert to EEGLAB .set format
%    02 - Add standard channel locations 
%    03 - Line noise removal and bandpass filtering 
%    04 - Manual bad channel inspection and removal
%
%  Notes:
%    - For subject 19A, run `fix_dyad19.m` (in `supplement` directory) before executing this script from Step 2.
%    - Some steps require manual inspection (spectra, bad channel removal).
%
%  ------------------------------------------------------------------------

clear, clc, close all

% Initiate eeglab
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% Navigate to the root folder of the data
tmp = matlab.desktop.editor.getActive; % Get the current active file
current_dir = fileparts(tmp.Filename); % Get the directory of the current file
up_one_level = fullfile(current_dir, '..');
eeg_dir = fullfile(up_one_level);
cd(fullfile(eeg_dir));

% Select files from raw files to be processed
file_names = cellstr(uigetfile('00_Raw\\*.vhdr',  'vhdr Files (*.vhdr*)','MultiSelect','on'));

for i = 1:(length(file_names))

    filename = char(file_names(i));
    % Get sub and cond str
    filename_strip = strrep(filename, '.vhdr', '');

    %% Steps 01 Processing raw data

    EEG = pop_loadbv('00_Raw\\', filename, []);

    % Convert to SET file and save
    EEG = pop_saveset(EEG, strcat(filename_strip, '_SET.set'), '01_SET\\');

    %% Step 02 Add channel locations

    % Lookup for channel locations
    EEG = pop_chanedit( ...
        EEG, ...
        'lookup', 'C:\Program Files\eeglab2025.0.0\plugins\dipfit\standard_BEM\elec\standard_1005.elc');

    % Plot channel spectra and maps (make sure channels are loaded properly and note for abnormal channels)
    figure; pop_spectopo(EEG, 1, [EEG.xmin  EEG.xmax], 'EEG' , 'freq', [6 10 60], 'freqrange', [2 80], 'electrodes', 'off');

    % Just make sure there are location details for each electrode, no changes
    % needed usually
    pop_chanedit(EEG);

    % Wait to continue after check...
    input('Checked channel locations for this subject? Press enter to continue')

    % Save data with channel location checked
    EEG = pop_editset(EEG, 'setname', strcat(filename_strip, '_chan'));
    EEG = pop_saveset(EEG, strcat(filename_strip, '_chan.set'), '02_Chan\\');

    %% Step 3

    % Clean Line
    % nc = EEG.nbchan;
    nc = 32;
    % EEG = pop_cleanline(EEG, 'Bandwidth',5,'ChanCompIndices', 1:nc, 'SignalType','Channels','ComputeSpectralPower',false,'LineFrequencies',[60 120] ,'NormalizeSpectrum',false,'LineAlpha',0.01,'PaddingFactor',2,'PlotFigures',false,'ScanForLines',true,'SmoothingFactor',300,'VerbosityLevel',1,'SlidingWinLength',2,'SlidingWinStep',1);

    % Or notch filter
    EEG = pop_eegfiltnew(EEG, 58, 62, [], 1);

    % Filtering (remove high- and low-frequency noise)
    EEG = pop_basicfilter( ...
        EEG, ...
        1:32, ...
        'Boundary', 'boundary', ...
        'Cutoff', [1 40], ...
        'Design', 'butter', ...
        'Filter', 'bandpass', ...
        'Order', 4, ...
        'RemoveDC', 'on' ...
        );

    % Save dataset
    EEG = pop_editset(EEG, 'setname', strcat(filename_strip, '_filt'));
    EEG = pop_saveset(EEG, strcat(filename_strip, '_filt.set'), '03_Filtered\\');

    figure; pop_spectopo(EEG, 1, [EEG.xmin  EEG.xmax], 'EEG' , 'freq', [6 10 60], 'freqrange', [2 80], 'electrodes', 'off');
    input('Continue? Press Enter');

    %% Step 04 Remove bad channels

    completed = 0;

    while completed == 0

        % Plot for detecting bad channels
        pop_eegplot(EEG, 1, 1, 1);

        % Ask for which channels to remove
        rmchannel = input("Which channels are you removing, if any?\n" + ...
            "Enter in this format, without quotes, '{'Fp1','Fz','F3','F7'}'.\n" + ...
            "If none, just press enter:\n");

        % Check if input is empty
        if isempty(rmchannel)

            % Ask for confirmation
            confirm = input('You did not enter any channels. Is this correct? (Y/N)\n', 's');

            % Only proceed if confirmed
            if confirm == 'Y'
                disp('No channels to remove.');
                completed = 1;
            else
                disp("Let's try again!");
            end

        else

            % Ask for confirmation
            confirm = input(strcat('You entered: ', strjoin(string(rmchannel), ', '), '. Is this correct? (Y/N)\n'), 's');

            % Only proceed if confirmed
            if confirm == 'Y'
                EEGtemp = pop_select(EEG, 'nochannel', rmchannel);

                % Ask for confirmation
                confirm = input('Does the number of channels match what you input? (Y/N)\n', "s");
                if confirm == 'Y'
                    EEG = EEGtemp; % Confirm the temporarily removed channels
                    completed = 1;
                else
                    disp("Let's try again!");
                end

            else
                disp("Let's try again!");
            end
        end
    end

    % Save dataset
    EEG = pop_editset(EEG, 'setname', strcat(filename_strip, '_rmChan'));
    EEG = pop_saveset(EEG, strcat(filename_strip, '_rmChan.set'), '04_rmChan\\');

end

% % Bonus (if needed): Fix event labels due to "stuck LSB / extra edge" trigger problem (Dyads 6 and 7).

% indices of events whose type is exactly 'S  1'
% isS1 = arrayfun(@(e) ischar(e.type) && ~isempty(regexp(e.type,'^S\s+1$','once')), EEG.event);
% EEG.event(isS1) = [];
% EEG = eeg_checkset(EEG,'eventconsistency');
% 
% % --- Collect S xx  ---
% N = numel(EEG.event);
% idxS = find(arrayfun(@(e) ischar(e.type) && startsWith(e.type,'S '), EEG.event));
% [~, ord] = sort([EEG.event(idxS).latency]);
% idxS = idxS(ord);
% 
% getNum = @(s) sscanf(s,'S %d');
% 
% % expected block per condition (tens digit)
% expected = containers.Map('KeyType','double','ValueType','double');
% 
% for ii = 1:numel(idxS)
%     k = idxS(ii);
%     v = getNum(EEG.event(k).type);        % e.g., 35
%     if isempty(v) || v==1, continue; end  % safety
% 
%     cond = floor(v/10);                   % e.g., 3x family
%     blk  = mod(v,10);                     % ones digit
% 
%     if ~isKey(expected,cond), expected(cond) = 1; end
%     expblk = expected(cond);
% 
%     if blk == expblk + 1
%         % skipped one: subtract 1 (e.g., 3 -> 2)
%         blk = blk - 1;
%         EEG.event(k).type = sprintf('S %d', cond*10 + blk);
%         expected(cond) = expblk + 1;      
%     elseif blk == expblk
%         % as expected: advance
%         expected(cond) = expblk + 1;
%     else
%         % anything else? leave-as-is
%     end
% end
% 
% EEG = eeg_checkset(EEG,'eventconsistency');
% 
% % Check it worked well:
% % isT1 = arrayfun(@(e) ischar(e.type) && ~isempty(regexp(e.type,'^T\s+1$','once')), EEG.event);
% % {EEG.event(~isT1).type}
% 
% EEG = pop_editset(EEG, 'setname', strcat(filename_strip, '_rmChan'));
% EEG = pop_saveset(EEG, strcat(filename_strip, '_rmChan.set'), '04_rmChan\\');