function pos = pointtobox_fix(pos,boxsize)
% 
if(nargin < 2)
    boxsize = 40;
end

for n = 1:length(pos)
    points = pos(n).point;
    for p = 1:size(points,1)
      pos(n).x1(p) = points(p,1) - boxsize/2;
      pos(n).y1(p) = points(p,2) - boxsize/2;
      pos(n).x2(p) = points(p,1) + boxsize/2;
      pos(n).y2(p) = points(p,2) + boxsize/2;
    end
end
