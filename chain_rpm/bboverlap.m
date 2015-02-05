function ovs = bboverlap(bbox,testbb)
% bbox (1,k)
% testbb (n,k)
% TODO: deal with bbox and testbb have same dim

bx1 = bbox(1);
by1 = bbox(2);
bx2 = bbox(3);
by2 = bbox(4);

x1 = testbb(:,1)';
y1 = testbb(:,2)';
x2 = testbb(:,3)';
y2 = testbb(:,4)';

% Compute intersection with bbox
xx1 = max(x1,bx1);
xx2 = min(x2,bx2);
yy1 = max(y1,by1);
yy2 = min(y2,by2);
w = xx2 - xx1 + 1;
h = yy2 - yy1 + 1;
w(w<0) = 0;
h(h<0) = 0;
inter  = h .* w;

% area of (possibly clipped) detection windows and original bbox
area = (y2-y1+1) .* (x2-x1+1);
box = (by2-by1+1) * (bx2-bx1+1);

ovs = inter ./ (area + box - inter);

