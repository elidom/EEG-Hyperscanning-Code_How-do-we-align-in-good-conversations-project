function [segments, tmp] = hyper_split_speakers(brain_data, sgmts, mask_data)

% -------------------------------------------------------------------------
% HYPER_SPLIT_SPEAKERS  Extract masked speaker-specific EEG segments.
%
%   [segments, tmp] = hyper_split_speakers(brain_data, sgmts, mask_data)
%
%   Author: Marcos E. Domínguez Arriola
%   Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
%            How Do We Align in Good Conversation?
%   Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
%
%   INPUTS:
%       brain_data - EEG matrix (channels × time)
%       sgmts      - Speaker turn intervals [start end] (samples)
%       mask_data  - Artifact mask intervals [start end] (samples)
%
%   OUTPUTS:
%       segments   - Concatenated EEG segments after mask removal
%       tmp        - Start/end indices of retained segments
%
%   DESCRIPTION:
%       Splits speaker turn intervals by removing overlapping artifact
%       mask segments. Intervals shorter than 2000 samples (~4 s at 500 Hz)
%       are discarded. Remaining segments are concatenated for analysis.
%
% -------------------------------------------------------------------------

segments = [];
    w = 1;
    for j = 1:size(sgmts,1)
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
        
        % Append each remaining interval if it's at least 2000 samples (4 seconds) long
        for segIdx = 1:size(intervals,1)
            segStart = intervals(segIdx, 1);
            segEnd   = intervals(segIdx, 2);
            if (segEnd - segStart + 1) >= 2000
                newSegBegn = size(segments,2) + 1;
                newSegEnd = newSegBegn + (segEnd - segStart);

                tmp(w,:) = [segStart segEnd];
                w = w+1;

                segments(:, newSegBegn:newSegEnd) = brain_data(:, segStart:segEnd);
            end
        end
    end
end
