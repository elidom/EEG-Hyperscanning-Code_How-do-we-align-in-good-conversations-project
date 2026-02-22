% Accept either a cell array of segments (each N×2) or a numeric N×2 array
if iscell(sgmts)
    S = vertcat(sgmts{:});   % concatenate all [start end] rows
else
    S = sgmts;
end

B = bcdata;

% Basic sanity checks
if size(S,2)~=2 || size(B,2)~=2
    error('Both sgmts and bcdata must have exactly 2 columns: [start end].');
end
if any(S(:,1) > S(:,2))
    bad = find(S(:,1) > S(:,2),1);
    error('sgmts has start > end (row %d).', bad);
end
if any(B(:,1) > B(:,2))
    bad = find(B(:,1) > B(:,2),1);
    error('bcdata has start > end (row %d).', bad);
end

% Containment test (allow tiny numerical tolerance if needed)
epsTol = 1e-9;
contains = @(b1,b2) (S(:,1) <= b1+epsTol) & (b2-epsTol <= S(:,2));

numB = size(B,1);
counts = zeros(numB,1);
whichSeg = NaN(numB,1);

for ii = 1:numB
    c = contains(B(ii,1), B(ii,2));
    counts(ii) = sum(c);
    if counts(ii) == 1
        whichSeg(ii) = find(c);
    end
end

% Throw errors if any bcdata segment is in zero or multiple sgmts segments
idxZero     = find(counts == 0);
idxMultiple = find(counts > 1);

if ~isempty(idxZero) || ~isempty(idxMultiple)
    msg = "";
    if ~isempty(idxZero)
        msg = msg + sprintf('Not contained in any sgmts segment: bcdata rows %s.\n', mat2str(idxZero(:)'));
    end
    if ~isempty(idxMultiple)
        msg = msg + sprintf('Contained in MULTIPLE sgmts segments: bcdata rows %s.\n', mat2str(idxMultiple(:)'));
    end
    error('%s', msg);
end

% If we get here, every bcdata row is contained in exactly one sgmts row
fprintf('All %d bcdata segments are fully contained in exactly one sgmts segment.\n', numB);
% Optional: show the mapping (bcdata row -> sgmts row)
