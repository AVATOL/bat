function loss = detect_loss(param, ytruth, ypred)
% for each box, if intersection(box,gt) / union(box,gt) < overlap,
% loss = loss + 1/numparts
%
% TODO: 1) try normalized distance
%       2) try truncated GMM loss

numparts = length(param.parts);
overlap = param.overlap;

xy = reshape(ypred.bbox(1:end-2),[4,numparts]);
xygt = reshape(ytruth.bbox(1:end-2),[4,numparts]);

loss = 0;
for k = 1:numparts
  x1 = xy(1,k);
  y1 = xy(2,k);
  x2 = xy(3,k);
  y2 = xy(4,k);
  
  bx1 = xygt(1,k);
  by1 = xygt(2,k);
  bx2 = xygt(3,k);
  by2 = xygt(4,k);
  
  % Compute intersection with bbox
  xx1 = max(x1,bx1);
  xx2 = min(x2,bx2);
  yy1 = max(y1,by1);
  yy2 = min(y2,by2);
  w = xx2 - xx1 + 1;
  h = yy2 - yy1 + 1;
  w(w<0) = 0;
  h(h<0) = 0;
  inter  = h'*w;
  
  % area of (possibly clipped) detection windows and original bbox
  area = (y2-y1+1)'*(x2-x1+1);
  box = (by2-by1+1)*(bx2-bx1+1);

  % thresholded overlap
  if inter / (area + box - inter) < overlap
    loss = loss + 1/numparts;
  end
end