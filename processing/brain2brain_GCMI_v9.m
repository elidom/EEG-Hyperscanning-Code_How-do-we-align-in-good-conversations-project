% -------------------------------------------------------------------------
%  Inter-Brain GCMI 
%
%  Author: Marcos E. Domínguez-Arriola
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%           How Do We Align in Good Conversation?
%  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%
%  Computes inter-brain Gaussian Copula Mutual Information (GCMI)
%  between dyad partners across time lags in alpha and theta bands.
%
%  Notes:
%      - Uses gcmi toolbox (https://github.com/robince/gcmi)
%      - User needs to make available custom functions within the `util`
%      directory.
% -------------------------------------------------------------------------

clear, clc, close all
tic;

subs = [4:14 16:28]; % which dyads to process

T = table('Size', [0 8], ...
                'VariableTypes', {'cell', 'double', 'string','string','double', 'double', 'string','string'}, ...
                'VariableNames', {'Trial', 'EffectiveLength', 'Channel_A','Channel_B', 'SyncMI', 'RcrrMI', 'FrequencyBand', 'Dyad'});

for dyad = subs

    dyadnum = sprintf('%02d', dyad);

    %% Step 1: Load and epoch each dataset
    
    nameA = ['hyperEngaging_dyad_' dyadnum '_REST_A.set'];
    nameB = ['hyperEngaging_dyad_' dyadnum '_REST_B.set'];
    
    % Epoch datasets using custom function
    sub_A = hyper_epoching(nameA, 'ready_data_v1');
    sub_B = hyper_epoching(nameB, 'ready_data_v1');
    
    % Check if both datasets have the same number of epochs
    nEpochs_A = size(sub_A, 1);
    nEpochs_B = size(sub_B, 1);
    
    if nEpochs_A ~= nEpochs_B
        disp('!!! Error: Datasets are of different size.');
    else
        % Check if all second columns (e.g., event codes) match
        labels_A = string(sub_A(:,2));
        labels_B = string(sub_B(:,2));
        nMatching = sum(labels_A == labels_B);
    
        if nMatching == nEpochs_A
            disp('# ----------------- Two datasets epoched successfully ----------------- #');
        else
            disp('!!! Error: One or more mismatches found between datasets.');
        end
    end
    
    %% Step 2: Prepare EEG-only Cell Arrays and Confirm that Trial Length Matches
    
    % Misc Parameters
    Nblock =   size(sub_A, 1);
    Nch    = size(sub_B{1,1}, 1); 
    eeg_fs = 500;
    
    % Initialize arrays
    info_A = cell(Nblock, 1);
    eeg_A = cell(Nblock, 1);
    
    info_B = cell(Nblock, 1);
    eeg_B = cell(Nblock, 1);
    
    % Extract EEG data from trials (SUB A)
    for i = 1:Nblock
        % Subject A
        curr_data_temp_A = sub_A{i, 1};                 % Current trial EEG data
        curr_data_A = curr_data_temp_A(1:33, :);   % Stim track (channel 65)
        info_A{i} = sub_A{i, 2};                        % Store trial information
        eeg_A{i} = curr_data_A;                        % Store EEG data
        
        % Subject B
        curr_data_temp_B = sub_B{i, 1};                 % Current trial EEG data
        curr_data_B = curr_data_temp_B(1:33, :);   % Stim track (channel 65)
        info_B{i} = sub_B{i, 2};                        % Store trial information
        eeg_B{i} = curr_data_B;                        % Store EEG data
    end
    
    temp_count = 0;
    for s = 1:Nblock
        size1 = size(eeg_A{s},2);
        size2 = size(eeg_B{s},2);
        if size1 == size2
            temp_count = temp_count + 1;
        end
    end
    if temp_count == Nblock
        disp('# - - - - - - - - - Trial length matches across datasets! - - - - - - - - - #')
    end
    
    %% Step 3: Apply Filters and Compute Gradients
    
    % - - - - - - - - - - Alpha
    fs = 500;         
    order = 2000; % Filter order
    low_cutoff = 7.8 / (fs/2);    
    high_cutoff = 13.2 / (fs/2);  
    b = fir1(order, [low_cutoff high_cutoff], 'bandpass');
    
    %figure;
    %freqz(b, 1, 1024, fs); % viz!
    
    % Prepare for filtering
    alpha_A   = cell(Nblock, 1);
    d_alpha_A = cell(Nblock, 1);
    alpha_B   = cell(Nblock, 1);
    d_alpha_B = cell(Nblock, 1);
    
    % Filter the data and compute gradients
    for bi = 1:Nblock
        % Filter the sub-A
        filteredData = filtfilt(b, 1, double(eeg_A{bi})');
        alpha_A{bi} = filteredData';
        
        % Filter the sub-B
        filteredData = filtfilt(b, 1, double(eeg_B{bi})');
        alpha_B{bi} = filteredData';
        
        % this optional, add gradient to 2d calculation (could smooth out filter oscilations)
        d_alpha_A{bi} = gradient_dim1(alpha_A{bi});
        d_alpha_B{bi} = gradient_dim1(alpha_B{bi});
    end
    
    disp('# -- Alpha done -- #')
    
    
    % - - - - - - - - - - - Theta
    fs = 500;         
    order = 2000;      % Filter order 
    
    low_cutoff = 1.8 / (fs/2);    
    high_cutoff = 8.2 / (fs/2); 
    b = fir1(order, [low_cutoff high_cutoff], 'bandpass');
    
    % figure;
    % freqz(b, 1, 1024, fs);
    
    % Prepare for filtering EEG and audio signals between 2-10 Hz
    theta_A   = cell(Nblock, 1);
    d_theta_A = cell(Nblock, 1);
    theta_B   = cell(Nblock, 1);
    d_theta_B = cell(Nblock, 1);
    
    % Filter the data and compute gradients
    for bi = 1:Nblock
    
        % Filter the sub-A
        filteredData = filtfilt(b, 1, double(eeg_A{bi})');
        theta_A{bi} = filteredData';
        
        % Filter the sub-B
        filteredData = filtfilt(b, 1, double(eeg_B{bi})');
        theta_B{bi} = filteredData';
    
        % this optional, add gradient to 2d calculation (could smooth out filter oscilations)
        d_theta_A{bi} = gradient_dim1(theta_A{bi});
        d_theta_B{bi} = gradient_dim1(theta_B{bi});
    end
    
    disp('# -- Theta done -- #')
    
    %% Separate data by speaker/listener relationship for each frequency band
    
    % Define which trials are conversations
    isConversation = string(sub_A(:,2)) == "HighInterest" | string(sub_A(:,2)) == "LowInterest";
    convIdx = find(isConversation);
    
    % Organize frequency band data into cell arrays for subject A and B
    bandNames = {'alpha', 'theta'};
    data_A = {alpha_A, theta_A};
    data_B = {alpha_B, theta_B};
    
    % Preallocate output cell arrays for each frequency band.
    % Each cell in these arrays will itself be a cell array for each conversation trial.
    brain_A_WhenSpeaks_A = cell(length(bandNames), 1);
    brain_A_WhenSpeaks_B = cell(length(bandNames), 1);
    brain_B_WhenSpeaks_A = cell(length(bandNames), 1);
    brain_B_WhenSpeaks_B = cell(length(bandNames), 1);
    
    % Initialize the output for each band
    for b = 1:length(bandNames)
        brain_A_WhenSpeaks_A{b} = cell(length(convIdx),1);
        brain_A_WhenSpeaks_B{b} = cell(length(convIdx),1);
        brain_B_WhenSpeaks_A{b} = cell(length(convIdx),1);
        brain_B_WhenSpeaks_B{b} = cell(length(convIdx),1);
    end
    
    % Loop over each conversation trial
    counter = 1;
    for i = convIdx'
        % Get the shared trial information once (masks and speaker segmentations)
        mask_data   = sub_A{i,4};
        spkrA_sgmts = sub_A{i,5};
        spkrB_sgmts = sub_A{i,6};
        
        % Loop over each frequency band
        for b = 1:length(bandNames)
            % Select current frequency band data for both subjects
            brain_data_A = data_A{b}{i};
            brain_data_B = data_B{b}{i};
            
            % Consistency checks
            if ~any(size(brain_data_A) == size(brain_data_B))
                error("Sizes do not match across neural datasets!")
            end
            if any(~any(mask_data == sub_B{i,4}))
                if ~isnan(mask_data) || ~isnan(sub_B{i, 4})
                    error("Mask segments do not correspond across datasets!")
                end
            end
            if any(~any(spkrA_sgmts == sub_B{i,5}))
                error("Speaker A segments do not correspond across datasets!")
            end
            if any(~any(spkrB_sgmts == sub_B{i,6}))
                error("Speaker B segments do not correspond across datasets!")
            end
            
            % Split the data for each speaker-listener relationship
            brain_A_WhenSpeaks_A{b}{counter} = hyper_split_speakers(brain_data_A, spkrA_sgmts, mask_data); % util function
            brain_A_WhenSpeaks_B{b}{counter} = hyper_split_speakers(brain_data_A, spkrB_sgmts, mask_data);
            brain_B_WhenSpeaks_A{b}{counter} = hyper_split_speakers(brain_data_B, spkrA_sgmts, mask_data);
            brain_B_WhenSpeaks_B{b}{counter} = hyper_split_speakers(brain_data_B, spkrB_sgmts, mask_data);
        end
        counter = counter + 1;
    end
    
    disp('# -- Speaker/Listener splitting done for all frequency bands -- #')
    
    %% Create information structure for each trial and frequency band
    
    numBands = numel(bandNames);
    
    % Initialize output cell arrays for Brain A and Brain B for each frequency band
    out_brainA = cell(numBands, 1);
    out_brainB = cell(numBands, 1);
    for b = 1:numBands
        out_brainA{b} = {};  % Each row: {splitData, Speaker, Condition, Index, FrequencyBand}
        out_brainB{b} = {};
    end
    
    % Loop through each frequency band
    for b = 1:numBands
        % Loop through each conversation trial (convIdx holds indices for HighInterest or LowInterest)
        for i = 1:length(convIdx)
            convIdx_i = convIdx(i);
            % Extract condition and index information from sub_A
            condition = sub_A{convIdx_i, 2};  
            index = sub_A{convIdx_i, 3};
    
            % For Brain A:
            % When Speaker A speaks
            out_brainA{b}(end+1, :) = {brain_A_WhenSpeaks_A{b}{i}, 'Speaker A', condition, index, bandNames{b}};
            % When Speaker B speaks
            out_brainA{b}(end+1, :) = {brain_A_WhenSpeaks_B{b}{i}, 'Speaker B', condition, index, bandNames{b}};
            
            % For Brain B:
            % When Speaker A speaks
            out_brainB{b}(end+1, :) = {brain_B_WhenSpeaks_A{b}{i}, 'Speaker A', condition, index, bandNames{b}};
            % When Speaker B speaks
            out_brainB{b}(end+1, :) = {brain_B_WhenSpeaks_B{b}{i}, 'Speaker B', condition, index, bandNames{b}};
        end
    end
    
    disp('# -- Output structure created for all frequency bands -- #')
    
    
    %% Add non-conversation trials for each frequency band
    nonConvIdx = find(~isConversation);
    
    % Preallocate cell arrays for non-conversation outputs for each frequency band
    nonconv_brainA = cell(numBands, 1);
    nonconv_brainB = cell(numBands, 1);
    for b = 1:numBands
        nonconv_brainA{b} = {};
        nonconv_brainB{b} = {};
    end
    
    % Loop through each non-conversation trial and each frequency band
    for b = 1:numBands
        for i = 1:length(nonConvIdx)
            trialIdx = nonConvIdx(i);
            condition = sub_A{trialIdx, 2};  % "Listening" or "Silence"
            trialIndex = sub_A{trialIdx, 3};
            
            % Use the appropriate frequency band data from data_A and data_B
            nonconv_brainA{b}(end+1, :) = {data_A{b}{trialIdx}, 'none', condition, trialIndex, bandNames{b}};
            nonconv_brainB{b}(end+1, :) = {data_B{b}{trialIdx}, 'none', condition, trialIndex, bandNames{b}};
        end
    end
    
    %% Prepend non-conversation trials to the conversation outputs for each frequency band
    final_out_brainA = cell(numBands, 1);
    final_out_brainB = cell(numBands, 1);
    for b = 1:numBands
        % Concatenate non-conversation trials (which now have 5 columns: data, speaker label, condition, index, band)
        % with the conversation trials already stored in out_brainA{b} and out_brainB{b}
        final_out_brainA{b} = [nonconv_brainA{b}; out_brainA{b}];
        final_out_brainB{b} = [nonconv_brainB{b}; out_brainB{b}];
    end
    
    %% Add signal length to the right for later normalization (DEPRECATED)
    getSignalLength = @(data) size(data, 2);  % Helper to count columns (signal length)
    
    % Now add a new column with the signal length.
    % Because our data now have 5 columns, the new column will be the 6th.
    for b = 1:numBands
        for i = 1:size(final_out_brainA{b}, 1)
            final_out_brainA{b}{i, 6} = getSignalLength(final_out_brainA{b}{i, 1});
        end
        
        for i = 1:size(final_out_brainB{b}, 1)
            final_out_brainB{b}{i, 6} = getSignalLength(final_out_brainB{b}{i, 1});
        end
    end
    
    disp('# -- Non-conversation trials added and final outputs constructed for all frequency bands -- #')
    
    %% Compute Inter-Brain Relationship With Time Lags for Each Frequency Band
    
    % Structure to store results for each frequency band
    final_results = struct();
    
    for b = 1:numBands
        % Extract the data column (the first column holds the EEG matrix)
        split_A = final_out_brainA{b}(:, 1);
        split_B = final_out_brainB{b}(:, 1);
    
        speaksinfo = final_out_brainA{b}(:, 2);

        Nblock = numel(split_B);
        % Determine the number of channels 
        Nch = size(split_A{1}, 1);  
    
        % Define time lags (in samples) and compute other lag parameters
        lags = -12:4:150;
    
        Nlags = length(lags);
        lagtime = lags ./ eeg_fs;    % convert lags to seconds
        L_max = max(abs(lags));
    
        % Preallocate results matrix: dimensions: [trial, lag, channel_A, channel_B]
        results = nan(Nblock, Nlags, Nch, Nch);
    
        % parfor to loop over trials (each trial is independent)
        parfor bi = 1:Nblock
            % For each trial, extract the EEG matrix and copula normalize
            brain_A = copnorm(split_A{bi}(1:33,:)')';  
            brain_B = copnorm(split_B{bi}(1:33,:)')';  

            who_speaker = speaksinfo{bi};
    
            for li = 1:Nlags
                l = lags(li);
                % Align signals based on lag
                if l == 0
                    % Zero lag: trim a fixed number of samples (L_max)
                    samples2trim = L_max;
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = size(brain_A, 2) - floor(samples2trim/2);
                    Alag = brain_A(:, idx_start:idx_end);
                    Blag = brain_B(:, idx_start:idx_end);
                elseif l < 0
                    % Negative lag: What does this mean: stim precedes resp.
                    lag_abs = abs(l);
                    samples2trim = L_max - lag_abs;
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = size(brain_A, 2) - floor(samples2trim/2);
                    A_segment = brain_A(:, idx_start:idx_end);
                    B_segment = brain_B(:, idx_start:idx_end);

                    if who_speaker == "Speaker B"
                        Blag = B_segment(:, 1:end - lag_abs);
                        Alag = A_segment(:, lag_abs + 1:end);
                    else
                        Alag = A_segment(:, 1:end - lag_abs);
                        Blag = B_segment(:, lag_abs + 1:end);
                    end

                else % l > 0
                    % Positive lag: response precedes stimulus
                    samples2trim = L_max - l;
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = size(brain_A, 2) - floor(samples2trim/2);
                    A_segment = brain_A(:, idx_start:idx_end);
                    B_segment = brain_B(:, idx_start:idx_end);

                    if who_speaker == "Speaker B"
                        Blag = B_segment(:, l + 1:end);
                        Alag = A_segment(:, 1:end - l);
                    else
                        Alag = A_segment(:, l + 1:end);
                        Blag = B_segment(:, 1:end - l);
                    end
                end
    
                % Loop over channels of subject A and B to compute MI
                for chi = 1:Nch
                    chan_A = Alag(chi, :);
                    for cha = 1:Nch
                        chan_B = Blag(cha, :);
    
                        sync = mi_gg(chan_A', chan_B', true, true);  % compute mutual information
                        
                        results(bi, li, chi, cha) = sync;
                    end
                end
            end
            % disp(['Frequency Band ' bandNames{b} ', Block ' num2str(bi) '/' num2str(Nblock) ' done!'])
        end
        elapsedTime = toc;
        fprintf('Frequency Band %s Elapsed time: %.4f hours\n', bandNames{b}, elapsedTime/3600);
    
        % Store raw results for the current frequency band
        final_results.(bandNames{b}).raw = results;
    
        %% Normalize results for current frequency band
        effective_lengths = zeros(Nblock, 1);
        for bi = 1:Nblock
            % For normalization, compute the effective signal length using the l=0 trimming
            samples2trim = L_max;
            idx_start = ceil(samples2trim/2) + 1;
            idx_end = size(split_A{bi}, 2) - floor(samples2trim/2);
            effective_lengths(bi) = idx_end - idx_start + 1;
        end
    
        % Apply a correction to account for differences in effective trial lengths
        normalized_results = results;
        for bi = 1:Nblock
            normalized_results(bi, :, :, :) = results(bi, :, :, :) * effective_lengths(bi);
        end
        
        % compute concurrent and recurrent gcmi for trials and electrodes
        sync_win = abs(lagtime) <= 0.025; % -24 - 24 ms (concurrence)
        rcrr_win = lagtime > 0.05;        % > 50 ms     (recurrence)

        sync_vals = squeeze( max(normalized_results(:, sync_win, :, :), [], 2) );
        rcrr_vals = squeeze( max(normalized_results(:, rcrr_win, :, :), [], 2) );
        
        final_results.(bandNames{b}).sync_MI = sync_vals;
        final_results.(bandNames{b}).rcrr_MI = rcrr_vals;
        final_results.(bandNames{b}).efflens = effective_lengths;

    end
    
    disp('# -- Inter-Brain Coordination Computation Completed for All Frequency Bands -- #')
    
    
    %% Try this to export data
    
    % channels = [sub_B{1,7}; "Stimtrack"];
    channels = [sub_B{1,7}];
    
    tmp = final_out_brainA{1}(:,2:4);
    trial_idx = {};
    for i = 1:size(tmp, 1)
        trial_idx{i} = [char(tmp{i,2}) '_' char(tmp{i,1}) '_' num2str(tmp{i,3})];
    end
    
    for b = 1:numBands
        % Get the normalized MI results for the current band
        sync_results = final_results.(bandNames{b}).sync_MI;
        rcrr_results = final_results.(bandNames{b}).rcrr_MI;
        
        % Determine dimensions
        [Nblock, Nch, ~] = size(sync_results);
    
        % Create grids of indices for trials, lags, channels
        [trialIdx, chanAIdx, chanBIdx] = ndgrid(trial_idx, channels, channels);
        [efflengths, ~, ~]             = ndgrid(effective_lengths, channels, channels); 

        % Flatten the indices and MI values
        trial_flat    = trialIdx(:);
        lengths_flat  = efflengths(:);
        chanA_flat    = chanAIdx(:);
        chanB_flat    = chanBIdx(:);
        sync_flat     = sync_results(:);
        rcrr_flat     = rcrr_results(:);
        
        % Create a table with columns for Trial, Lag, Channel A, Channel B, MI, and Frequency Band
        TTemp = table(trial_flat, lengths_flat, chanA_flat, chanB_flat, sync_flat, rcrr_flat, ...
                  'VariableNames', {'Trial', 'EffectiveLength', 'Channel_A', 'Channel_B', 'SyncMI', 'RcrrMI'});
        % Add frequency band information (as a string column)
        TTemp.FrequencyBand = repmat({bandNames{b}}, height(TTemp), 1);
        TTemp.Dyad = repmat(['Dyad' dyadnum], height(TTemp), 1);
                
        T = [T; TTemp];

        % optional to-do: add export of full raw data matrix

    end
    elapsedTime = toc;
    fprintf('# - - - - GCMI ~ Dyad %s completed. Time elapsed: %.4f hours\n - - - - #', dyadnum, elapsedTime/3600);
end

filename = fullfile('output', '11_gcmi_quick', 'brain2brain_gcmi.csv');
writetable(T, filename);
