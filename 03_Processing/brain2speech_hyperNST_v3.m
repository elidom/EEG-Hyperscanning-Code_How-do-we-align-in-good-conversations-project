% -------------------------------------------------------------------------
% HYPER NEURAL SPEECH TRACKING GCMI estimation
%
% Author: Marcos E. Domínguez Arriola
% Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%          How Do We Align in Good Conversation?
% Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%
% DESCRIPTION:
%   Computes Neural Speech Tracking (NST) using lagged Gaussian Copula
%   Mutual Information (GCMI) between speech envelope and EEG activity
%   in hyperscanning dyads.
%
% -------------------------------------------------------------------------

clear, clc, close all

subs = [4:14 16:28];% Dyads to process

outDir = 'output/9a_NST';
final_results = struct();

for sub = subs

    dyadNum = sprintf('%02d', sub);
    
    % dir info
    audioDir = ['../5_preprocessing/Audio/00_Clean_Audio_Files/dyad' dyadNum];
    csvDir   = ['../5_preprocessing/Audio/06_as_csv/Dyad' dyadNum];
    eegdir   = '../5_preprocessing/EEG/13_REST';
    auxdir   = '../5_preprocessing/EEG/13a_auxONLY';
    
    % file info
    wavFilesInfo1 = dir(fullfile(audioDir, '*.wav'));
    wavFilesInfo2 = {wavFilesInfo1.name};
    
    csvFilesInfo1 = dir(fullfile(csvDir, '*.xlsx'));
    csvFilesInfo2 = {csvFilesInfo1.name};
    
    eegFilesInfo1 = dir(fullfile(eegdir, '*.set'));
    eegFilesInfo2 = string({eegFilesInfo1.name});
    which2read = contains(eegFilesInfo2, ['dyad_' dyadNum]);
    sets2read = eegFilesInfo2(which2read);
    sets2read = sort(sets2read);
    subAsetFile = fullfile(eegdir, sets2read(1));
    subBsetFile = fullfile(eegdir, sets2read(2));
    
    auxFilesInfo1 = dir(fullfile(auxdir, '*.set'));
    auxFilesInfo2 = string({auxFilesInfo1.name});
    which2read = contains(auxFilesInfo2, ['dyad_' dyadNum]);
    aux2read = auxFilesInfo2(which2read);
    auxFile = fullfile(auxdir, aux2read);
    
    % Run epoching function
    subA = epoching4NT(subAsetFile, auxFile);
    subA(:,[6 9]) = [];
    
    subB = epoching4NT(subBsetFile, auxFile);
    subB(:,[7 8]) = [];
    
    splitA = splitTurnsForNST(subA); 
    splitB = splitTurnsForNST(subB); 
    
    %% PARTICIPANT A
    
    % Set parameters
    Nblock = size(splitA, 1);  % trials
    eeg_fs = 500;              
    Nch = 33;  
    
    % Initialize cell arrays for envelopes and EEG data
    envs = cell(Nblock, 1);
    eegs = cell(Nblock, 1);
    info = cell(Nblock, 1);
    
    % Extract envelopes and EEG data from trials
    for i = 1:Nblock
        curr_data = splitA{i, 1};               % Current trial EEG data
        curr_strak = splitA{i, 2}';         % Stim track 
        curr_eegs = curr_data';        % EEG channels
        info{i} = [char(splitA{i, 4}) '_' num2str(splitA{i, 5})];
        envs{i} = curr_strak;                   % stimulus envelope
        eegs{i} = curr_eegs;                    % EEG data
    end
    
    fny   = eeg_fs/2;
    order = 501;   % ≈ 3001 taps  (odd for linear phase)
    b = fir1(order-1, [1 10]/fny, hamming(order));   % band-pass
    a = 1;                                            % FIR
    
    stim  = cell(1,Nblock);
    resp  = cell(1,Nblock);
    dstim = cell(1,Nblock);
    dresp = cell(1,Nblock);
    
    % Filter the data and compute gradients
    for bi = 1:Nblock
        % Filter the speech envelope signal 
        stim_untrimmed = filtfilt(b, a, double(envs{bi}));
    
        % trim flat ends
        stim{bi} = stim_untrimmed(201:length(stim_untrimmed)-201);
    
        % Filter  EEG response
        resp_untrimmed = filtfilt(b, a, double(eegs{bi})); 
    
        % trim flat ends
        resp{bi} = resp_untrimmed(201:length(resp_untrimmed)-201,:);
    
        % add gradient
        dstim{bi} = gradient_dim1(stim{bi});
        dresp{bi} = gradient_dim1(resp{bi});
    end
    
    
    disp('- - - - - - - - Data filtered - - - - - - - -')
    
    
    % Copula normalization
    cstim = cellfun(@(x) copnorm(x), stim, 'UniformOutput', false);
    cresp = cellfun(@(x) copnorm(x), resp, 'UniformOutput', false);  
    
    cdstim = cellfun(@(x) copnorm(x), dstim, 'UniformOutput', false);
    cdresp = cellfun(@(x) copnorm(x), dresp, 'UniformOutput', false); 
    
    
    % Define lags -200 to 200 samples in steps of 2 (4 ms)
    lags = -200:2:200;
    Nlags = length(lags);
    lagtime = lags ./ eeg_fs;    % lags to time in seconds
    
    lagmi3d = nan(Nch,Nlags,Nblock);

    for bi = 1:Nblock
    
        stim_bi = cstim{bi};
        resp_bi = cresp{bi};
        dstim_bi = cdstim{bi};
        dresp_bi = cdresp{bi};
    
        L_max = max(abs(lags));
        
        for li = 1:Nlags
            l = lags(li);
    
            if l == 0
                    % Zero lag
        
                    samples2trim = L_max;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    slag = stim_bi(idx_start:idx_end);
                    rlag = resp_bi(idx_start:idx_end, :);
                    dslag = dstim_bi(idx_start:idx_end);
                    drlag = dresp_bi(idx_start:idx_end, :);
                  
        
                elseif l < 0
                    % Negative lag: stimulus before response
                    lag_abs = abs(l);
        
                    samples2trim = L_max - lag_abs;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    stim_segment = stim_bi(idx_start:idx_end);
                    resp_segment = resp_bi(idx_start:idx_end, :);
                    dstim_segment = dstim_bi(idx_start:idx_end);
                    dresp_segment = dresp_bi(idx_start:idx_end, :);
        
                    slag = stim_segment(1:end - lag_abs);
                    rlag = resp_segment(lag_abs + 1:end, :);
                    dslag = dstim_segment(1:end - lag_abs);
                    drlag = dresp_segment(lag_abs + 1:end, :);
        
                    % size(slag) % size remains constant across lags
                
                else % l > 0
                    % Positive lag: response before stimulus
                    
                    samples2trim = L_max - l;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    stim_segment = stim_bi(idx_start:idx_end);
                    resp_segment = resp_bi(idx_start:idx_end, :);
                    dstim_segment = dstim_bi(idx_start:idx_end);
                    dresp_segment = dresp_bi(idx_start:idx_end, :);
        
                    slag = stim_segment(l + 1:end);
                    rlag = resp_segment(1:end - l, :);
                    dslag = dstim_segment(l + 1:end);
                    drlag = dresp_segment(1:end - l, :);
        
            end 
    
            % Loop over electrodes
            for chi = 1:Nch
                
                stim_vars = [slag, dslag];
                resp_vars = [rlag(:, chi), drlag(:, chi)];
                
                % Compute and store MIs 
                lagmi3d(chi, li, bi) = mi_gg(stim_vars, resp_vars, true, true);
            end
        end
        disp(['Trial ' num2str(bi) ' computed.'])
    end
    
    final_results.raw_subA = lagmi3d;

    % normalize A
    effective_lengths = zeros(Nblock,1);

    for bi = 1:Nblock
        samples2trim = L_max;
        idx_start = ceil(samples2trim/2) + 1;
        idx_end   = size(cstim{bi},1) - floor(samples2trim/2);
        effective_lengths(bi) = idx_end - idx_start+1;
    end

    normed_lagmi = lagmi3d;
    for bi = 1:Nblock
        normed_lagmi(:,:,bi) = lagmi3d(:,:,bi) * effective_lengths(bi);
    end

    final_results.normed_subA = normed_lagmi;
    
    %% PARTICIPANT B
    
    % Set parameters
    Nblock = size(splitB, 1);  % Number of trials
    eeg_fs = 500;              
    Nch = 33;  

   
    % Initialize cell arrays for envelopes and EEG data
    envs = cell(Nblock, 1);
    eegs = cell(Nblock, 1);
    info = cell(Nblock, 1);
    
    % Extract envelopes and EEG data from trials
    for i = 1:Nblock
        curr_data = splitB{i, 1};               % Current trial EEG data
        curr_strak = splitB{i, 2}';         % Stim track (channel 65)
        curr_eegs = curr_data';        % EEG channels 1 to 64
        info{i} = [char(splitB{i, 4}) '_' num2str(splitB{i, 5})];
        envs{i} = curr_strak;                   % Store stimulus envelope
        eegs{i} = curr_eegs;                    % Store EEG data
    end
    
    fny   = eeg_fs/2;
    order = 501;   % ≈ 3001 taps  (odd for linear phase)
    b = fir1(order-1, [1 10]/fny, hamming(order));   % band-pass
    a = 1;                                            % FIR 
    
    stim  = cell(1,Nblock);
    resp  = cell(1,Nblock);
    dstim = cell(1,Nblock);
    dresp = cell(1,Nblock);
    
    % Filter the data and compute gradients
    for bi = 1:Nblock
        % Filter the speech envelope signal 
        stim_untrimmed = filtfilt(b, a, double(envs{bi}));
    
        % trim  flat ends
        stim{bi} = stim_untrimmed(201:length(stim_untrimmed)-201);
    
        % Filter EEG response
        resp_untrimmed = filtfilt(b, a, double(eegs{bi})); %% HEY! I think this is filtering across the wrong direction!! can use '2' argument to specify the direction
    
        % trim flat ends
        resp{bi} = resp_untrimmed(201:length(resp_untrimmed)-201,:);
    
        % add gradient
        dstim{bi} = gradient_dim1(stim{bi});
        dresp{bi} = gradient_dim1(resp{bi});
    end
    % 
    
    disp('- - - - - - - - Data filtered - - - - - - - -')
    
    
    % Copula normalization
    cstim = cellfun(@(x) copnorm(x), stim, 'UniformOutput', false);
    cresp = cellfun(@(x) copnorm(x), resp, 'UniformOutput', false);  
    
    cdstim = cellfun(@(x) copnorm(x), dstim, 'UniformOutput', false);
    cdresp = cellfun(@(x) copnorm(x), dresp, 'UniformOutput', false); 
    
    
    % Define lags -200 to 200 samples in steps of 2 (4 ms)
    lags = -200:2:200;
    Nlags = length(lags);
    lagtime = lags ./ eeg_fs;    
    
    lagmi3dB = nan(Nch,Nlags,Nblock);
    
    
    for bi = 1:Nblock
    
        stim_bi = cstim{bi};
        resp_bi = cresp{bi};
        dstim_bi = cdstim{bi};
        dresp_bi = cdresp{bi};
    
        L_max = max(abs(lags));
        
        for li = 1:Nlags
            l = lags(li);
    
            if l == 0
                    % Zero lag
        
                    samples2trim = L_max;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    slag = stim_bi(idx_start:idx_end);
                    rlag = resp_bi(idx_start:idx_end, :);
                    dslag = dstim_bi(idx_start:idx_end);
                    drlag = dresp_bi(idx_start:idx_end, :);
                  
        
                elseif l < 0
                    % Negative lag: stimulus before response
                    lag_abs = abs(l);
        
                    samples2trim = L_max - lag_abs;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    stim_segment = stim_bi(idx_start:idx_end);
                    resp_segment = resp_bi(idx_start:idx_end, :);
                    dstim_segment = dstim_bi(idx_start:idx_end);
                    dresp_segment = dresp_bi(idx_start:idx_end, :);
        
                    slag = stim_segment(1:end - lag_abs);
                    rlag = resp_segment(lag_abs + 1:end, :);
                    dslag = dstim_segment(1:end - lag_abs);
                    drlag = dresp_segment(lag_abs + 1:end, :);
        
                    % size(slag) % size remains constant across lag values
                
                else % l > 0
                    % Positive lag: response before stimulus
                    
                    samples2trim = L_max - l;
                    
                    idx_start = ceil(samples2trim/2) + 1;
                    idx_end = length(stim_bi) - floor(samples2trim/2);
        
                    stim_segment = stim_bi(idx_start:idx_end);
                    resp_segment = resp_bi(idx_start:idx_end, :);
                    dstim_segment = dstim_bi(idx_start:idx_end);
                    dresp_segment = dresp_bi(idx_start:idx_end, :);
        
                    slag = stim_segment(l + 1:end);
                    rlag = resp_segment(1:end - l, :);
                    dslag = dstim_segment(l + 1:end);
                    drlag = dresp_segment(1:end - l, :);
        
            end 
    
            % Loop over electrodes
            for chi = 1:Nch
                
                stim_vars = [slag, dslag];
                resp_vars = [rlag(:, chi), drlag(:, chi)];
                
                % Compute and store MIs 
                lagmi3dB(chi, li, bi) = mi_gg(stim_vars, resp_vars, true, true);
            end
        end
        disp(['Trial ' num2str(bi) ' computed.'])
    end 

    final_results.raw_subB = lagmi3dB;

    % normalize B
    effective_lengths = zeros(Nblock,1);

    for bi = 1:Nblock
        samples2trim = L_max;
        idx_start = ceil(samples2trim/2) + 1;
        idx_end   = size(cstim{bi},1) - floor(samples2trim/2);
        effective_lengths(bi) = idx_end - idx_start+1;
    end

    normed_lagmiB = lagmi3dB;
    for bi = 1:Nblock
        normed_lagmiB(:,:,bi) = lagmi3dB(:,:,bi) * effective_lengths(bi);
    end

    final_results.normed_subB = normed_lagmiB;

    %% EXPORT

    % Common metadata grids (same for A/B)
    [Nch, Nlags, NblockA] = size(final_results.raw_subA);
    [lagIdx, chIdx] = ndgrid(1:Nlags, 1:Nch);      
    ch_vec  = chIdx(:);                             
    lag_vec = lagIdx(:);                            
    labs = subA{1,8};
    
    % Helper for converting lags to vectors
    Lag_samples_vec = int16(lags(lag_vec));         
    Lag_sec_vec     = lagtime(lag_vec);             
    
    % -------- Speaker A --------
    rowsPerBlock = numel(ch_vec);
    TA_parts = cell(NblockA,1);
    for bi = 1:NblockA
        % meta
        cond_i  = string(splitA{bi,4});             % "HighInterest"/"LowInterest"
        block_i = double(splitA{bi,5});             
        
        % MI -> vector (lags major, then channels)
        raw_blk  = permute(final_results.raw_subA(:,:,bi),  [2 1]);  % [Nlags x Nch]
        norm_blk = permute(final_results.normed_subA(:,:,bi),[2 1]);
        MI_raw_vec  = raw_blk(:);
        MI_norm_vec = norm_blk(:);
        channlabels = labs(ch_vec);
    
        % build table for this block
        TA_parts{bi} = table( ...
            repmat("D"+dyadNum, rowsPerBlock, 1), ...
            repmat("A",        rowsPerBlock, 1), ...
            repmat(cond_i,     rowsPerBlock, 1), ...
            repmat(block_i,    rowsPerBlock, 1), ...
            uint16(ch_vec), ...
            channlabels, ...
            Lag_samples_vec', ...
            Lag_sec_vec', ...
            MI_raw_vec, ...
            MI_norm_vec, ...
            'VariableNames', {'Dyad','Speaker','Condition','Block','Channel', 'ChannelLabel', ...
                              'Lag_samples','Lag_sec','MI_raw','MI_norm'} );
    end
    T_A = vertcat(TA_parts{:});
    
    % -------- Speaker B --------
    [~, ~, NblockB] = size(final_results.raw_subB);
    TB_parts = cell(NblockB,1);
    for bi = 1:NblockB
        cond_i  = string(splitB{bi,4});
        block_i = double(splitB{bi,5});
        
        raw_blk  = permute(final_results.raw_subB(:,:,bi),  [2 1]);  % [Nlags x Nch]
        norm_blk = permute(final_results.normed_subB(:,:,bi),[2 1]);
        MI_raw_vec  = raw_blk(:);
        MI_norm_vec = norm_blk(:);
    
        TB_parts{bi} = table( ...
            repmat("D"+dyadNum, rowsPerBlock, 1), ...
            repmat("B",        rowsPerBlock, 1), ...
            repmat(cond_i,     rowsPerBlock, 1), ...
            repmat(block_i,    rowsPerBlock, 1), ...
            uint16(ch_vec), ...
            channlabels, ...
            Lag_samples_vec', ...
            Lag_sec_vec', ...
            MI_raw_vec, ...
            MI_norm_vec, ...
            'VariableNames', {'Dyad','Speaker','Condition','Block','Channel', 'ChannelLabel', ...
                              'Lag_samples','Lag_sec','MI_raw','MI_norm'} );
    end
    T_B = vertcat(TB_parts{:});
    
    % Combine & write 
    T_dyad = [T_A; T_B];
    outfile = fullfile(outDir, sprintf('lagMI_NST_long_dyad_%s.csv', dyadNum));
    writetable(T_dyad, outfile);
    fprintf('Saved: %s (rows=%d)\n', outfile, height(T_dyad));

end
