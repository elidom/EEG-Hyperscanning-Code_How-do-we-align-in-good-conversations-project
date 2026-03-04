% -------------------------------------------------------------------------
%  CONTROL ANALYSIS – Surrogate Inter-Brain *Recurrent* Coordination (GCMI)
%
%  Author: Marcos E. Domínguez Arriola
%  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%           How Do We Align in Good Conversation?
%
%  Generates surrogate inter-brain datasets by pairing speakers
%  from different dyads. For each surrogate pairing, computes recurrent GCMI 
%  across EEG channels during conversational trials.
%
%  OVERVIEW:
%      1. Randomly generate surrogate dyad pairings
%      2. Epoch EEG datasets for each participant
%      3. Band-pass filter signals
%      4. Segment speech turns 
%      5. Compute lagged inter-brain GCMI across channels
%      6. Normalize MI values by signal length
%      7. Extract peak recurrent MI
%      8. Export surrogate datasets for downstream analysis
%
%  NOTES:
%      - This version computes recurrent (listener-lagging) GCMI only.
%      - Requires the same `util` functions as `postprocessing`
%
% -------------------------------------------------------------------------

clear, clc, close all
tic;

nmetasurs = 1:200;
nsurs = 24;
subs = [4:14 16:28];

for metasur = nmetasurs

    T = table('Size', [0 7], ...
                'VariableTypes', {'cell','string','string','double','string','string','string'}, ...
                'VariableNames', {'Trial','Channel_A','Channel_B', 'RcrrMI', 'FrequencyBand', 'Subject_A', 'Subject_B'});
    
    rng(metasur+1042)
    allPairs = nchoosek(subs, 2);
    idx = randperm(size(allPairs,1), nsurs);
    pairs = allPairs(idx, :);
    sur = 0;
    
    for dyadi = 1:size(pairs,1)
    
        dyadA = pairs(dyadi,1);
        dyadB = pairs(dyadi,2);
        
        dyadnum_A = sprintf('%02d', dyadA);
        dyadnum_B = sprintf('%02d', dyadB);
        
        nameA = ['hyperEngaging_dyad_' dyadnum_A '_REST_A.set'];
        nameB = ['hyperEngaging_dyad_' dyadnum_B '_REST_B.set'];
        
        % Epoch datasets
        sub_A = hyper_epoching(nameA, 'ready_data_v1');
        sub_B = hyper_epoching(nameB, 'ready_data_v1');
        
        %% Step 2: Prepare EEG-only Cell Arrays
        
        % Misc Parameters
        Nblock =   min([size(sub_A, 1),  size(sub_B, 1)]);
        Nch    = size(sub_B{1,1}, 1); 
        eeg_fs = 500;
        
        % Quick fix if one dyad is #4 (which is missing trials)
        if dyadA==4 
            sub_B = sub_B([2:6 8:12 13:end],:);
        end
    
        if dyadB==4 
            sub_A = sub_A([2:6 8:12 13:end],:);
        end
    
        % Initialize arrays
        info_A = cell(Nblock, 1);
        eeg_A = cell(Nblock, 1);
        
        info_B = cell(Nblock, 1);
        eeg_B = cell(Nblock, 1);
        
        % Extract EEG data from trials (SUB A)
        for i = 1:Nblock
            % Subject A
            curr_data_temp_A = sub_A{i, 1};                 
            curr_data_A = curr_data_temp_A(1:33, :);        
            info_A{i} = sub_A{i, 2};                        
            eeg_A{i} = curr_data_A;                         
            
            
            % Subject B
            curr_data_temp_B = sub_B{i, 1};                 
            curr_data_B = curr_data_temp_B(1:33, :);   
            info_B{i} = sub_B{i, 2};                        
            eeg_B{i} = curr_data_B;                        
        end
        
        
        %% Step 3: Apply Filters 
        
        % - - - - - - - - - - Alpha
        fs = 500;         
        order = 2000; 
        low_cutoff = 7.8 / (fs/2);    
        high_cutoff = 13.2 / (fs/2);  
        b = fir1(order, [low_cutoff high_cutoff], 'bandpass');
        
        % diagnose
        %figure;
        %freqz(b, 1, 1024, fs);
        %title('Frequency Response of the Alpha Band FIR Filter');
        
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
            
            % add gradient to 2d calculation (this could smooth out filter oscilations)
            d_alpha_A{bi} = gradient_dim1(alpha_A{bi});
            d_alpha_B{bi} = gradient_dim1(alpha_B{bi});
        end
        
        % disp('# -- Alpha done -- #')
        
        % - - - - - - - - - - - Theta
        fs = 500;         
        order = 2000;      % Filter order 

        low_cutoff = 1.8 / (fs/2);    
        high_cutoff = 8.2 / (fs/2); 
        b = fir1(order, [low_cutoff high_cutoff], 'bandpass');

        % diagnose
        % figure;
        % freqz(b, 1, 1024, fs);
        % title('Frequency Response of the Theta Band FIR Filter');

        % Prepare for filtering 
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

            % add gradient to 2d calculation (this could smooth out filter oscilations)
            d_theta_A{bi} = gradient_dim1(theta_A{bi});
            d_theta_B{bi} = gradient_dim1(theta_B{bi});
        end
        
        % disp('# -- Theta done -- #')
        
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
            mask_data_A   = sub_A{i,4};
            mask_data_B   = sub_B{i,4};
    
            spkrA_sgmts_indataA = sub_A{i,5};
            spkrB_sgmts_indataA = sub_A{i,6};
            spkrA_sgmts_indataB = sub_B{i,5};
            spkrB_sgmts_indataB = sub_B{i,6};
            
            % Loop over each frequency band
            for b = 1:length(bandNames)
                % Select current frequency band data for both subjects
                brain_data_A = data_A{b}{i};
                brain_data_B = data_B{b}{i};
                
                % Split the data for each speaker-listener relationship
                brain_A_WhenSpeaks_A{b}{counter} = hyper_split_speakers(brain_data_A, spkrA_sgmts_indataA, mask_data_A);
                brain_A_WhenSpeaks_B{b}{counter} = hyper_split_speakers(brain_data_A, spkrB_sgmts_indataA, mask_data_A);
                brain_B_WhenSpeaks_A{b}{counter} = hyper_split_speakers(brain_data_B, spkrA_sgmts_indataB, mask_data_B);
                brain_B_WhenSpeaks_B{b}{counter} = hyper_split_speakers(brain_data_B, spkrB_sgmts_indataB, mask_data_B);
            end
            counter = counter + 1;
        end
        
        % disp('# -- Speaker/Listener splitting done for all frequency bands -- #')
        
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
        
        % disp('# -- Output structure created for all frequency bands -- #')
        
        %% Compute Inter-Brain Relationship With Time Lags for Each Frequency Band
        
        % Structure to store results
        final_results = struct();
    
        for b = 1:numBands
            % Extract the data column (the first column holds the EEG matrix)
            split_A = out_brainA{b}(:, 1);
            split_B = out_brainB{b}(:, 1);
    
            speaksinfo = out_brainA{b}(:, 2);
        
            Nblock = numel(split_B);
            Nch = size(split_A{1}, 1);  
        
            % Define time lags (in samples) and compute other lag parameters
            lags = 24:4:150;
        
            Nlags = length(lags);
            lagtime = lags ./ eeg_fs;    %  lags to seconds
            L_max = max(abs(lags));
        
            % Preallocate  dimensions: [trial, lag, channel_A, channel_B]
            results = nan(Nblock, Nlags, Nch, Nch);
        
            % Use parfor  (each trial is independent)
            parfor bi = 1:Nblock
                % For each trial, extract the EEG matrix and copula normalize
                brain_A = copnorm(split_A{bi}(1:33,:)')';  
                brain_B = copnorm(split_B{bi}(1:33,:)')';  
    
                % EDIT: We have to reconcile signal lengths
                AL = size(brain_A,2);
                BL = size(brain_B,2);
    
                if AL > BL
                    brain_A = brain_A(:,1:BL);
                elseif BL > AL
                    brain_B = brain_B(:,1:AL);
                end
                % end of edit
    
                % EDIT: identify who is the speaker, and apply the lags only to
                % the listener.
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
                        % Negative lag: What does this mean: B precedes A.
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
        
            %% Normalize results for current frequency band
            effective_lengths = zeros(Nblock, 1);
            for bi = 1:Nblock
                % For normalization, compute the effective signal length using the l=0 trimming
                samples2trim = L_max;
                idx_start = ceil(samples2trim/2) + 1;
                idx_end = size(split_A{bi}, 2) - floor(samples2trim/2);
                effective_lengths(bi) = idx_end - idx_start + 1;
            end
        
            % Apply a correction factor to account for differences in effective trial lengths
            normalized_results = results;
            for bi = 1:Nblock
                normalized_results(bi, :, :, :) = results(bi, :, :, :) * effective_lengths(bi);
            end
        
            % compute overall max and latency of max
            [max_MI, peak_idx] = max(normalized_results, [], 2);
            max_MI = squeeze(max_MI);        %  Nblock × Nch × Nch
        
            final_results.(bandNames{b}).max_MI = max_MI;
        end
        
        
        %% Export data
        channels = [sub_B{1,7}];
        
        tmp = out_brainA{1}(:,2:4);
        trial_idx = {};
        for i = 1:size(tmp, 1)
            trial_idx{i} = [char(tmp{i,2}) '_' char(tmp{i,1}) '_' num2str(tmp{i,3})];
        end
        
        for b = 1:numBands
            peak_MI      = final_results.(bandNames{b}).max_MI;        
            
            % dimensions
            [Nblock, Nch, ~] = size(peak_MI);
        
            % Create grids of indices for trials, lags, channels
            [trialIdx, chanAIdx, chanBIdx] = ndgrid(trial_idx, channels, channels);
            
            % Flatten the indices and MI values
            trial_flat  = trialIdx(:);
            chanA_flat  = chanAIdx(:);
            chanB_flat  = chanBIdx(:);
            MI_flat     = peak_MI(:);
            
            % Create a table 
            TTemp = table(trial_flat, chanA_flat, chanB_flat, MI_flat, ...
                      'VariableNames', {'Trial', 'Channel_A', 'Channel_B', 'RcrrMI'});
    
            % Add information 
            TTemp.FrequencyBand = repmat(bandNames{b}, height(TTemp), 1);
            TTemp.Subject_A = repmat(['Dyad' dyadnum_A '_A'], height(TTemp), 1);
            TTemp.Subject_B = repmat(['Dyad' dyadnum_B '_B'], height(TTemp), 1);
    
            T = [T; TTemp]; %#ok<AGROW>
            
        end
        
        sur = sur+1;
        elapsedTime = toc;
        fprintf('\n\n# - - - - Meta: %s - Surrogate %s completed. Time elapsed: %.4f hours - - - - #\n\n', num2str(metasur), num2str(sur), elapsedTime/3600);
    end
    
    filename = fullfile('output', '10b_shuffled_dyads', ['gcmi_rcrr_shuffled_surrogates_' num2str(metasur) '.csv']); 
    writetable(T, filename);
    
end