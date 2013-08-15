function tsize = init_part_size(pos,sbin,initPartID)
% determine the model size of a part given its pos examples

if nargin < 3
    initPartID = 1;
end

w = zeros(1,length(pos));
h = zeros(1,length(pos));
for n = 1:length(pos)
  w(n) = pos(n).x2(initPartID) - pos(n).x1(initPartID) + 1;
  h(n) = pos(n).y2(initPartID) - pos(n).y1(initPartID) + 1;
end

% nw = mode(w);
% nh = mode(h);
nw = mean(w);
nh = mean(h);
nf = length(features(zeros([3 3 3]),1));

tsize = [floor(nh/sbin) floor(nw/sbin) nf];