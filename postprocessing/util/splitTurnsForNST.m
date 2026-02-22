function split_data = splitTurnsForNST(subarray)
   
% -------------------------------------------------------------------------
% SPLITTURNSFORNST  Extract speaker-specific EEG & envelope segments for NST.
%
%   split_data = splitTurnsForNST(subarray)
%
%   Author: Marcos E. Domínguez Arriola
%   Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%            How Do We Align in Good Conversation?
%   Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%
%   INPUT:
%       subarray  - Trial-level cell array containing:
%                   {EEG, envelope, condition, trial number,
%                    mask segments, speaker turns, backchannels}
%
%   OUTPUT:
%       split_data - Cell array per trial:
%           {EEG_segments, envelope_segments, segment_indices,
%            condition, trial_number}
%
%   DESCRIPTION:
%       For each trial, extracts the listener's neural data during
%       the partner's speaking turns. Artifact masks and self-
%       backchannels are removed. Segments shorter than 500 samples
%       (~1 s at 500 Hz) are discarded. Remaining segments are
%       concatenated for Neural Speech Tracking (NST) analysis.
%
% -------------------------------------------------------------------------

    all_resp = subarray(:,1); % speaker A brain data
    all_stim = subarray(:,2);
    all_masks = subarray(:,5);
    turnsInTrial = subarray(:,6); % other speaker's speaking turns
    all_bcs = subarray(:,7); % self backchannels

    all_types = subarray(:,3);
    all_nums  = subarray(:,4);
    
    % initialize return variable
    split_data = cell(size(all_resp,1),5);
    
    for i = 1:size(turnsInTrial,1)
        % disp(['i = ' num2str(i)])

        brain_data = all_resp{i};
        stimdata   = all_stim{i};
        sgmts = turnsInTrial{i};
        mask_data = all_masks{i};
        bcdata = all_bcs{i};

        ttype = all_types{i};
        tnum  = all_nums{i};

        run('util/check_bcs.m')

        brainsegments = [];
        stimsegments  = [];
        tmp = [];  
        w = 1;

        for j = 1:size(sgmts,1)
            % disp(['j = ' num2str(j)])
            % Define the initial speaking turn interval
            spkrStart = round(sgmts(j,1));
            spkrEnd   = round(sgmts(j,2));
            intervals = [spkrStart, spkrEnd];  % may be more than one row after splitting
            
            % Process each mask segment
            for m = 1:size(mask_data, 1)
                maskStart = round(mask_data(m, 1));
                
                if isnan(maskStart)
                    maskEnd   = NaN;
                else
                    maskEnd   = round(mask_data(m, 2));
                end
    
                newIntervals = [];
                
                % Process each current interval (could be >1 after splits)
                for k = 1:size(intervals, 1)
                    intStart = intervals(k, 1);
                    intEnd   = intervals(k, 2);
                    
                    % No overlap
                    if maskEnd < intStart || maskStart > intEnd
                        newIntervals = [newIntervals; intStart, intEnd]; %#ok<*AGROW> 
                    else
                        % Mask fully covers the interval: drop it.
                        if maskStart <= intStart && maskEnd >= intEnd
                            continue
                        else
                            % Mask fully inside the interval: split into left/right parts.
                            if maskStart > intStart && maskEnd < intEnd
                                left_length = maskStart - intStart;
                                right_length = intEnd - maskEnd;
                                if left_length >= 1000
                                    newIntervals = [newIntervals; intStart, maskStart - 1];
                                end
                                if right_length >= 1000
                                    newIntervals = [newIntervals; maskEnd + 1, intEnd];
                                end
                            % Partial overlap at beginning: adjust start.
                            elseif maskStart <= intStart && maskEnd < intEnd
                                newIntStart = maskEnd + 1;
                                newIntervals = [newIntervals; newIntStart, intEnd];
                            % Partial overlap at end: adjust end.
                            elseif maskStart > intStart && maskEnd >= intEnd
                                newIntEnd = maskStart - 1;
                                newIntervals = [newIntervals; intStart, newIntEnd];
                            % Mask is NaN
                            elseif isnan(maskStart) && isnan(maskEnd)
                                newIntervals = [newIntervals; intStart, intEnd];
                            end
                        end
                    end
                end
                
                % Update intervals with new ones from this mask
                intervals = newIntervals;
                if isempty(intervals)
                    break; % no valid data remains in this segment
                end
            end

            %% Here let's do the same as above, but for backchannels
            
            % Process each mask segment
            for m = 1:size(bcdata, 1)
                bcStart = round(bcdata(m, 1));
                
                if isnan(bcStart)
                    bcEnd   = NaN;
                else
                    bcEnd   = round(bcdata(m, 2));
                end
    
                newIntervals = [];
                
                % Process each current interval (could be >1 after splits)
                for k = 1:size(intervals, 1)
                    intStart = intervals(k, 1);
                    intEnd   = intervals(k, 2);
                    
                    % No overlap
                    if bcEnd < intStart || bcStart > intEnd
                        newIntervals = [newIntervals; intStart, intEnd]; %#ok<*AGROW> 
                    else
                        % BC fully inside the interval (as should): split into left/right parts.
                        if bcStart > intStart && bcEnd < intEnd
                            left_length = bcStart - intStart;
                            right_length = intEnd - bcEnd;
                            if left_length >= 1000
                                newIntervals = [newIntervals; intStart, bcStart - 1];
                            end
                            if right_length >= 1000
                                newIntervals = [newIntervals; bcEnd + 1, intEnd];
                            end
                        
                        % BC is NaN (should never happen)
                        elseif isnan(bcStart) && isnan(bcEnd)
                            % newIntervals = [newIntervals; intStart, intEnd];
                            error('No Backchannels detected in this conversation! Check if this is ok.')
                        elseif bcStart <= intStart && bcEnd < intEnd % It can happen that a mask overlaps the BCs
                            
                            right_length = intEnd - bcEnd;
                            if right_length >= 1000
                                newIntervals = [newIntervals; bcEnd + 1, intEnd];
                            end

                        elseif bcStart > intStart && bcEnd >= intEnd
                            
                            left_length = bcStart - intStart;
                            if left_length >= 1000
                                newIntervals = [newIntervals; intStart, bcStart - 1];
                            end
                            
                        else
                            continue
                            % error('Something went wrong.')
                        end
                    end
                end
                
                % Update intervals with new ones from this mask
                intervals = newIntervals;
                if isempty(intervals)
                    break; % no valid data remains in this segment
                end
            end
            

            %% END
            
            % Append each remaining interval if it's at least 500 samples (1 second) long
            for segIdx = 1:size(intervals,1)
                segStart = intervals(segIdx, 1);
                segEnd   = intervals(segIdx, 2);
                if (segEnd - segStart + 1) >= 500
                    newSegBegn = size(brainsegments,2) + 1;
                    newSegEnd = newSegBegn + (segEnd - segStart);
    
                    tmp(w,:) = [segStart segEnd];
                    w = w+1;
    
                    brainsegments(:, newSegBegn:newSegEnd) = brain_data(:, segStart:segEnd);
                    stimsegments(:, newSegBegn:newSegEnd) = stimdata(:, segStart:segEnd);
                end
            end
        end
        split_data{i,1} = brainsegments;
        split_data{i,2} = stimsegments;
        split_data{i,3} = tmp;
        split_data{i,4} = ttype;
        split_data{i,5} = tnum;

    end
end
