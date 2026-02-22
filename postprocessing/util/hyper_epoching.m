function [epoched_data] = hyper_epoching(set_name, file_path)
   
% -------------------------------------------------------------------------
% HYPER_EPOCHING  Epoch hyperscanning EEG dataset by condition.
%
%   epoched_data = hyper_epoching(set_name, file_path)
%
%   Author: Marcos E. Domínguez Arriola
%   Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%            How Do We Align in Good Conversation?
%   Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%
%   INPUTS:
%       set_name   - EEGLAB .set filename
%       file_path  - Dataset directory
%
%   OUTPUT:
%       epoched_data - Cell array containing:
%           epoch data, condition label, trial index,
%           mask segments, speaker A segments, speaker B segments,
%           channel labels
%
%   DESCRIPTION:
%       Extracts Listening, Silence, HighInterest, and LowInterest
%       trials from a preprocessed dataset. Aligns artifact masks
%       and identifies speaker turn segments (backchannels removed).
%
% -------------------------------------------------------------------------

    % Load the EEG dataset
    datapath = file_path;
    EEG = pop_loadset('filename', set_name, 'filepath', datapath);
    
    % List of substrings to match for removal
    drop_substrings = {'T1', 'boundary'};
    
    % Get all codelabels from EEG.event
    codelabels = {EEG.event.codelabel};
    
    % Initialize logical array to mark events for removal
    remove_indices = false(1, length(codelabels));
    
    % Loop over each substring and find matching events
    for i = 1:length(drop_substrings)
        substring = drop_substrings{i};
        
        % For MATLAB R2016b and newer, use 'contains'
%         matches = contains(codelabels, substring);
        matches = strcmp(codelabels, substring);
        
        % Update the indices of events to remove
        remove_indices = remove_indices | matches;
    end
    
    % Indices of events to keep
    keep_indices = ~remove_indices;
    
    % Keep only the desired events in EEG.event
    EEG.event = EEG.event(keep_indices);
    
    % If urevent field exists, update it as well
    if ~isempty(EEG.urevent)
        EEG.urevent = EEG.urevent(keep_indices);
    end
    
    % Get the number of events
    n_events = length(EEG.event);

    % Save the mask
    mask = EEG.maskedIntervals;
    
    % Initialize the output cell array and counters
    epoched_data = {};
    w = 1;

    trimmed_labels = {EEG.event.codelabel};
    
    %% Part 1: Fetch listening trials
    
    %n_listening_trials = sum(contains(trimmed_labels(contains(trimmed_labels, "Listening")), "Onset"));
    tmp_counter = 0;

    for i = 1:6
        
        % Identify Listening events
        count_idx = contains(trimmed_labels, ['Listening_T' num2str(i)]);
        listening_idx = find(count_idx);
        
        % Check whether there is a beginning and end (i.e., two events of the type)
        if sum(count_idx) < 2
            warning(['Listening T' num2str(i) ' did not have 2 events.'])
            continue
        end
        
        % Fetch beginning and end latencies
        trial_start = EEG.event(listening_idx(1)).latency;
        trial_end = EEG.event(listening_idx(2)).latency;
        
        % Identify if any mask portion should be attached
        isMasked = mask >= trial_start & mask <= trial_end;
        
        % Check if any full mask segment falls in trial; store
        full_mask = sum(isMasked,2) == 2;
        full_mask_idx = full_mask;
        
        % Check if any mask segment partially falls in trial; store
        partial_mask = sum(isMasked,2) == 1;
        partial_idx  = find(partial_mask);
        
        % If there are partial segments, shift start/end of trial
        if sum(partial_mask) > 0
           for j = 1:numel(partial_idx)
                
               m  = mask(partial_idx(j),:);
               
               if m(1) < trial_start && m(2) < trial_end
                   
                   m(1) = trial_start+1;
               elseif m(2) > trial_end && m(1) > trial_start

                   m(2) = trial_end;
               end

               mask(partial_idx(j),:) = m; % modify mask to nnot exceed trial bounds

           end
        end

        % If there are full segments, scale and store them for later sue
        if sum(full_mask) > 0
            trial_mask = mask(full_mask_idx,:) - trial_start;
        else
            trial_mask = nan;
        end 

        % Extract the epoch data from the EEG
        epoch = EEG.data(:, trial_start:trial_end);
        
        % Store the data and trial type in the output cell array
        epoched_data{w, 1} = epoch;                   % epoch data
        epoched_data{w, 2} = "Listening";             % condition
        epoched_data{w, 3} = i;                       % counter
        epoched_data{w, 4} = trial_mask;              % mask info
        epoched_data{w, 5} = "none";                  % speaker A segments
        epoched_data{w, 6} = "none";                  % speaker B segments
        epoched_data{w, 7} = string({EEG.chanlocs.labels})'; % channels info
        
        % Increment the counters
        w = w + 1;
        tmp_counter = tmp_counter + 1;

    end

    % disp([num2str(tmp_counter) ' Listening trials processed!'])

    %% Part 2: Fetch silence trials
    
    tmp_counter = 0;

    for i = 1:6
        
        % Identify Listening events
        count_idx = contains(trimmed_labels, ['Silence_T' num2str(i)]);
        silence_idx = find(count_idx);
        
        % Check whether there is a beginning and end (i.e., two events of the type)
        if sum(count_idx) < 2
            warning(['Silence T' num2str(i) ' did not have 2 events.'])
            continue
        end
        
        % Fetch beginning and end latencies
        trial_start = EEG.event(silence_idx(1)).latency;
        trial_end = EEG.event(silence_idx(2)).latency;
        
        % Identify if any mask portion should be attached
        isMasked = mask >= trial_start & mask <= trial_end;
        
        % Check if any full mask segment falls in trial; store
        full_mask = sum(isMasked,2) == 2;
        full_mask_idx = full_mask;
        
        % Check if any mask segment partially falls in trial; store
        partial_mask = sum(isMasked,2) == 1;
        partial_idx  = find(partial_mask);
        
        % If there are partial segments, shift start/end of trial
        if sum(partial_mask) > 0
           for j = 1:numel(partial_idx)
                
               m  = mask(partial_idx(j),:);
               
               if m(1) < trial_start && m(2) < trial_end
                   
                   m(1) = trial_start+1;
               elseif m(2) > trial_end && m(1) > trial_start

                   m(2) = trial_end;
               end

               mask(partial_idx(j),:) = m; % modify mask to not exceed trial bounds

           end
        end

        % If there are full segments, scale and store them for later sue
        if sum(full_mask) > 0
            trial_mask = mask(full_mask_idx,:) - trial_start;
        else
            trial_mask = nan;
        end 

        % Extract the epoch data from the EEG
        epoch = EEG.data(:, trial_start:trial_end);
        
        % Store the data and trial type in the output cell array
        epoched_data{w, 1} = epoch;
        epoched_data{w, 2} = "Silence";
        epoched_data{w, 3} = i;
        epoched_data{w, 4} = trial_mask;
        epoched_data{w, 5} = "none";
        epoched_data{w, 6} = "none";
        epoched_data{w, 7} = string({EEG.chanlocs.labels})';
        
        % Increment the counters
        w = w + 1;
        tmp_counter = tmp_counter + 1;

    end

    % disp([num2str(tmp_counter) ' Silence trials processed!'])

    %% Part 3: Fetch High Interest Trials

    tmp_counter = 0;

    for i = 1:6
        
        % Identify High Interest events
        count_idx = contains(trimmed_labels, ['HighInterest_T' num2str(i)]);
        highInt_idx = find(count_idx);
        
        % Check whether there is a beginning and end (i.e., two events of the type)
        if sum(count_idx) < 2
            warning(['High Interest T' num2str(i) ' did not have 2 events.'])
            continue
        end
        
        % Fetch beginning and end latencies
        trial_start = EEG.event(highInt_idx(1)).latency;
        trial_end = EEG.event(highInt_idx(2)).latency;
        
        % Identify if any mask portion should be attached
        isMasked = mask >= trial_start & mask <= trial_end;
        
        % Check if any full mask segment falls in trial; store
        full_mask = sum(isMasked,2) == 2;
        full_mask_idx = full_mask;
        
        % Check if any mask segment partially falls in trial; store
        partial_mask = sum(isMasked,2) == 1;
        partial_idx  = find(partial_mask);
        
        % If there are partial segments, shift start/end of trial
        if sum(partial_mask) > 0
           for j = 1:numel(partial_idx)
                
               m  = mask(partial_idx(j),:);
               
               if m(1) < trial_start && m(2) < trial_end
                   
                   m(1) = trial_start+1;
               elseif m(2) > trial_end && m(1) > trial_start

                   m(2) = trial_end;
               end

               mask(partial_idx(j),:) = m; % modify mask to not exceed trial bounds

           end
        end

        % If there are full segments, scale and store them for later sue
        if sum(full_mask) > 0
            trial_mask = mask(full_mask_idx,:) - trial_start;
        else
            trial_mask = nan;
        end 

        % Extract the epoch data from the EEG
        epoch = EEG.data(:, trial_start:trial_end);

        % Identify the events within the trial
        eventsInTrial = EEG.event([EEG.event.latency] > trial_start & [EEG.event.latency] < trial_end); 
        codelabels = {eventsInTrial.codelabel}; % Convert to cell array

        % Identify Speaker A events
        isSpeakerA = contains(codelabels, "Speaker_A");
        Anumb = sum(isSpeakerA);
        A_Events = eventsInTrial(isSpeakerA);

        % Identify Speaker B events
        isSpeakerB = contains(codelabels, "Speaker_B");
        Bnumb = sum(isSpeakerB);
        B_Events = eventsInTrial(isSpeakerB);
        
        % Loop through speaker A turns
        whereisA = [];
        turn = 1;
        for k = 1:Anumb
            if k < Anumb
                curr = A_Events(k);
                foll = A_Events(k+1);

                if contains(curr.codelabel, "Start")
                    if contains(foll.codelabel, "End")
                        whereisA(turn,1) = curr.latency;
                        whereisA(turn,2) = foll.latency;
                        turn = turn + 1;
                    else
                        warning(['In Speaker A, a speaking event had no end.']);
                    end
                end
            else
                % If trial ends with speaker speaking, cut at end
                curr = A_Events(k);
                if contains(curr.codelabel, "Start")
                    whereisA(turn,1) = curr.latency;
                    whereisA(turn,2) = trial_end;
                end
            end
        end
        
        % Loop through speaker B turns
        whereisB = [];
        turn = 1;
        for k = 1:Bnumb
            if k < Bnumb
                curr = B_Events(k);
                foll = B_Events(k+1);

                if contains(curr.codelabel, "Start")
                    if contains(foll.codelabel, "End")
                        whereisB(turn,1) = curr.latency;
                        whereisB(turn,2) = foll.latency;
                        turn = turn + 1;
                    else
                        warning(['In Speaker B, a speaking event had no end.']);
                    end
                end
            else
                % If trial ends with speaker speaking, cut at end
                curr = B_Events(k);
                if contains(curr.codelabel, "Start")
                    whereisB(turn,1) = curr.latency; %#ok<*AGROW> 
                    whereisB(turn,2) = trial_end;
                end
            end
        end

%         (whereisA - trial_start) / 500
%         (whereisB - trial_start) / 500  % Good!
                
        
        % Here I will remove backchannel-type turns:
        ats = size(whereisA,1);
        bts = size(whereisB,1);
        
        abc = zeros(ats, 1);
        bbc = zeros(bts, 1);
        
        % A's turns:
        for j = 1:ats
            aturn = whereisA(j,:);                      % extract turn
            isBC2 = zeros(bts, 1);
            
            for k = 1:bts
                % see if the turn is contained in one of B's
                x = aturn(1) >= whereisB(k,1); 
                y = aturn(2) <= whereisB(k,2);
                isBC2(k) = x + y == 2;
            end

            if sum(isBC2) == 1
                abc(j) = 1;                             % add record
            elseif sum(isBC2) > 1
                error("Something went wrong.")
            end
        end
        
        % B's turns:
        for j = 1:bts
            bturn = whereisB(j,:);                      % extract turn
            isBC2 = zeros(ats, 1);
            
            for k = 1:ats
                % see if the turn is contained in one of A's
                x = bturn(1) >= whereisA(k,1); 
                y = bturn(2) <= whereisA(k,2);
                isBC2(k) = x + y == 2;
            end

            if sum(isBC2) == 1
                bbc(j) = 1;                             % add record
            elseif sum(isBC2) > 1
                error("Something went wrong2.")
            end
        end
        
        a_backchannels = find(abc);
        b_backchannels = find(bbc);

        whereisA(a_backchannels,:) = []; %#ok<*FNDSB>
        whereisB(b_backchannels,:) = []; 

        % Store the data and trial type in the output cell array
        epoched_data{w, 1} = epoch;                   % epoch data
        epoched_data{w, 2} = "HighInterest";          % condition
        epoched_data{w, 3} = i;                       % counter
        epoched_data{w, 4} = trial_mask;              % mask info
        epoched_data{w, 5} = whereisA - trial_start;  % speaker A segments
        epoched_data{w, 6} = whereisB - trial_start;  % speaker B segments
        epoched_data{w, 7} = string({EEG.chanlocs.labels})'; % channels info
        
        % Increment the counters
        w = w + 1;
        tmp_counter = tmp_counter + 1;

    end

    % disp([num2str(tmp_counter) ' High Interest trials processed!'])


    %% Part 4: Fetch Low Interest Trials

    tmp_counter = 0;

    for i = 1:6
        
        % Identify Listening events
        count_idx = contains(trimmed_labels, ['LowInterest_T' num2str(i)]);
        lowInt_idx = find(count_idx);
        
        % Check whether there is a beginning and end (i.e., two events of the type)
        if sum(count_idx) < 2
            warning(['Listening T' num2str(i) ' did not have 2 events.'])
            continue
        end
        
        % Fetch beginning and end latencies
        trial_start = EEG.event(lowInt_idx(1)).latency;
        trial_end = EEG.event(lowInt_idx(2)).latency;
        
        % Identify if any mask portion should be attached
        isMasked = mask >= trial_start & mask <= trial_end;
        
        % Check if any full mask segment falls in trial; store
        full_mask = sum(isMasked,2) == 2;
        full_mask_idx = full_mask;
        
        % Check if any mask segment partially falls in trial; store
        partial_mask = sum(isMasked,2) == 1;
        partial_idx  = find(partial_mask);
        
        % If there are partial segments, shift start/end of trial
        if sum(partial_mask) > 0
           for j = 1:numel(partial_idx)
                
               m  = mask(partial_idx(j),:);
               
               if m(1) < trial_start && m(2) < trial_end
                   
                   m(1) = trial_start+1;
               elseif m(2) > trial_end && m(1) > trial_start

                   m(2) = trial_end;
               end

               mask(partial_idx(j),:) = m; % modify mask to not exceed trial bounds

           end
        end

        % If there are full segments, scale and store them for later sue
        if sum(full_mask) > 0
            trial_mask = mask(full_mask_idx,:) - trial_start;
        else
            trial_mask = nan;
        end 

        % Extract the epoch data from the EEG
        epoch = EEG.data(:, trial_start:trial_end);

        % Identify the events within the trial
        eventsInTrial = EEG.event([EEG.event.latency] > trial_start & [EEG.event.latency] < trial_end); 
        codelabels = {eventsInTrial.codelabel}; % Convert to cell array

        % Identify Speaker A events
        isSpeakerA = contains(codelabels, "Speaker_A");
        Anumb = sum(isSpeakerA);
        A_Events = eventsInTrial(isSpeakerA);

        % Identify Speaker B events
        isSpeakerB = contains(codelabels, "Speaker_B");
        Bnumb = sum(isSpeakerB);
        B_Events = eventsInTrial(isSpeakerB);
        
        % Loop through speaker A turns
        whereisA = [];
        turn = 1;
        for k = 1:Anumb
            if k < Anumb
                curr = A_Events(k);
                foll = A_Events(k+1);

                if contains(curr.codelabel, "Start")
                    if contains(foll.codelabel, "End")
                        whereisA(turn,1) = curr.latency;
                        whereisA(turn,2) = foll.latency;
                        turn = turn + 1;
                    else
                        warning(['In Speaker A, a speaking event had no end.']);
                    end
                end
            else
                % If trial ends with speaker speaking, cut at end
                curr = A_Events(k);
                if contains(curr.codelabel, "Start")
                    whereisA(turn,1) = curr.latency;
                    whereisA(turn,2) = trial_end;
                end
            end
        end
        
        % Loop through speaker B turns
        whereisB = [];
        turn = 1;
        for k = 1:Bnumb
            if k < Bnumb
                curr = B_Events(k);
                foll = B_Events(k+1);

                if contains(curr.codelabel, "Start")
                    if contains(foll.codelabel, "End")
                        whereisB(turn,1) = curr.latency;
                        whereisB(turn,2) = foll.latency;
                        turn = turn + 1;
                    else
                        warning(['In Speaker B, a speaking event had no end.']);
                    end
                end
            else
                % If trial ends with speaker speaking, cut at end
                curr = B_Events(k);
                if contains(curr.codelabel, "Start")
                    whereisB(turn,1) = curr.latency; %#ok<*AGROW> 
                    whereisB(turn,2) = trial_end;
                end
            end
        end

%         (whereisA - trial_start) / 500
%         (whereisB - trial_start) / 500  % Good!

        % Remove backchannel-type turns:
        ats = size(whereisA,1);
        bts = size(whereisB,1);
        
        abc = zeros(ats, 1);
        bbc = zeros(bts, 1);
        
        % A's turns:
        for j = 1:ats
            aturn = whereisA(j,:);                      % extract turn
            isBC2 = zeros(bts, 1);
            
            for k = 1:bts
                % see if the turn is contained in one of B's
                x = aturn(1) >= whereisB(k,1); 
                y = aturn(2) <= whereisB(k,2);
                isBC2(k) = x + y == 2;
            end

            if sum(isBC2) == 1
                abc(j) = 1;                             % add record
            elseif sum(isBC2) > 1
                error("Something went wrong.")
            end
        end
        
        % B's turns:
        for j = 1:bts
            bturn = whereisB(j,:);                      % extract turn
            isBC2 = zeros(ats, 1);
            
            for k = 1:ats
                % see if the turn is contained in one of A's
                x = bturn(1) >= whereisA(k,1); 
                y = bturn(2) <= whereisA(k,2);
                isBC2(k) = x + y == 2;
            end

            if sum(isBC2) == 1
                bbc(j) = 1;                             % add record
            elseif sum(isBC2) > 1
                error("Something went wrong2.")
            end
        end
        
        a_backchannels = find(abc);
        b_backchannels = find(bbc);

        whereisA(a_backchannels,:) = []; 
        whereisB(b_backchannels,:) = [];
                

        % Store the data and trial type in the output cell array
        epoched_data{w, 1} = epoch;                   % epoch data
        epoched_data{w, 2} = "LowInterest";          % condition
        epoched_data{w, 3} = i;                       % counter
        epoched_data{w, 4} = trial_mask;              % mask info
        epoched_data{w, 5} = whereisA - trial_start;  % speaker A segments
        epoched_data{w, 6} = whereisB - trial_start;  % speaker B segments
        epoched_data{w, 7} = string({EEG.chanlocs.labels})'; % channels info
        
        % Increment the counters
        w = w + 1;
        tmp_counter = tmp_counter + 1;

    end

    % disp([num2str(tmp_counter) ' Low Interest trials processed!'])

end
