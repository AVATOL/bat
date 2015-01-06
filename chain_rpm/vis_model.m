function vis_model(model)
%

figure(1002); vis_templates(model);
title(sprintf('norm(w) = %f\n', norm(model.w,2)));
figure(1003); vis_deformations(model);


function vis_templates(model)
% visualize HOG templates

pad = 2;
bs = 20;
numparts = model.num_parts;

w = model.node(1).w;
w = foldHOG(w);
scale = max(abs(w(:)));
p = HOGpicture(w, bs);
p = padarray(p, [pad pad], 0);
p = uint8(p*(255/scale));    
% border 
p(:,1:2*pad) = 128;
p(:,end-2*pad+1:end) = 128;
p(1:2*pad,:) = 128;
p(end-2*pad+1:end,:) = 128;
im = p;
startpoint = zeros(numparts,2);
startpoint(1,:) = [0 0];

for k = 2:numparts
    parent = model.parent(k);

    w = model.node(k).w;
    w = foldHOG(w);
    scale = max(abs(w(:)));
    p = HOGpicture(w, bs);
    p = padarray(p, [pad pad], 0);
    p = uint8(p*(255/scale));    
    % border 
    p(:,1:2*pad) = 128;
    p(:,end-2*pad+1:end) = 128;
    p(1:2*pad,:) = 128;
    p(end-2*pad+1:end,:) = 128;

    % paste into root
    def = model.edge(k,parent);

    x1 = (def.anchor(1)-1)*bs+1 + startpoint(parent,1);
    y1 = (def.anchor(2)-1)*bs+1 + startpoint(parent,2);

    [H W] = size(im);
    imnew = zeros(H + max(0,1-y1), W + max(0,1-x1));
    imnew(1+max(0,1-y1):H+max(0,1-y1),1+max(0,1-x1):W+max(0,1-x1)) = im;
    im = imnew;

    startpoint = startpoint + repmat([max(0,1-x1) max(0,1-y1)],[numparts,1]);

    x1 = max(1,x1);
    y1 = max(1,y1);
    x2 = x1 + size(p,2)-1;
    y2 = y1 + size(p,1)-1;

    startpoint(k,1) = x1 - 1;
    startpoint(k,2) = y1 - 1;

    im(y1:y2, x1:x2) = p;
end

% plot parts   
imagesc(im); colormap gray; axis equal; axis off; drawnow;

function vis_deformations(model)
%

bs = 4;
numparts = model.num_parts;
point = zeros(numparts,2);
r = zeros(numparts,2);

point(1,:) = [bs*5/2+1,bs*5/2+1];
startpoint = zeros(numparts,2);
startpoint(1,:) = [0 0];

for k = 2:numparts
    parent = model.parent(k);
    
    % paste into root
    def = model.edge(k,parent);
    
    x1 = (def.anchor(1)-1)*bs+1 + startpoint(parent,1);
    y1 = (def.anchor(2)-1)*bs+1 + startpoint(parent,2);
    x2 = x1 + bs*5+1 -1;
    y2 = y1 + bs*5+1 -1;
    
    startpoint(k,1) = x1 - 1;
    startpoint(k,2) = y1 - 1;
    
    point(k,:) = [(x1+x2)/2,(y1+y2)/2];
    r(k,:) = [sqrt(1/2/def.w(1)) sqrt(1/2/def.w(3))];
end

pointall = point;
radius = r;

minx = min(pointall(:,1));
maxx = max(pointall(:,1));
miny = min(pointall(:,2));
maxy = max(pointall(:,2));

Xmin = min(minx);
Xmax = max(maxx);
Ymin = min(miny);
Ymax = max(maxy);

clf;
plot(pointall(:,1),-pointall(:,2),'b.','markersize',30);
hold on;
for k = 2:numparts
    parent = model.parent(k);
    line([pointall(parent,1) pointall(k,1)],-[pointall(parent,2) pointall(k,2)],'linewidth',4);
end
for k = 2:numparts
    ellipse(radius(k,1),radius(k,2),0,pointall(k,1),-pointall(k,2),'r');
end
axis off;
axis equal;
xlim([Xmin-10 Xmax+10]); ylim([-Ymax-10 -Ymin+10]);    
  
%    set(gcf,'position',get(0,'screensize'))
%    saveas(gcf,['skeleton_parse_' '.jpg']);
%    saveas(gcf,['skeleton_parse_' '.fig']);


%% helper functions
function f = foldHOG(w)
% f = foldHOG(w)
% Condense HOG features into one orientation histogram.
% Used for displaying a feature.

f=max(w(:,:,1:9),0)+max(w(:,:,10:18),0)+max(w(:,:,19:27),0);


function im = HOGpicture(w, bs)
% HOGpicture(w, bs)
% Make picture of positive HOG weights.

% construct a "glyph" for each orientaion
bim1 = zeros(bs, bs);
bim1(:,round(bs/2):round(bs/2)+1) = 1;
bim = zeros([size(bim1) 9]);
bim(:,:,1) = bim1;
for i = 2:9,
    bim(:,:,i) = imrotate(bim1, -(i-1)*20, 'crop');
end

% make pictures of positive weights bs adding up weighted glyphs
s = size(w);    
w(w < 0) = 0;    
im = zeros(bs*s(1), bs*s(2));
for i = 1:s(1),
    iis = (i-1)*bs+1:i*bs;
    for j = 1:s(2),
        jjs = (j-1)*bs+1:j*bs;          
        for k = 1:9,
            im(iis,jjs) = im(iis,jjs) + bim(:,:,k) * w(i,j,k);
        end
    end
end

function h=ellipse(ra,rb,ang,x0,y0,C,Nb)
% Ellipse adds ellipses to the current plot
%
% ELLIPSE(ra,rb,ang,x0,y0) adds an ellipse with semimajor axis of ra,
% a semimajor axis of radius rb, a semimajor axis of ang, centered at
% the point x0,y0.
%
% The length of ra, rb, and ang should be the same. 
% If ra is a vector of length L and x0,y0 scalars, L ellipses
% are added at point x0,y0.
% If ra is a scalar and x0,y0 vectors of length M, M ellipse are with the same 
% radii are added at the points x0,y0.
% If ra, x0, y0 are vectors of the same length L=M, M ellipses are added.
% If ra is a vector of length L and x0, y0 are  vectors of length
% M~=L, L*M ellipses are added, at each point x0,y0, L ellipses of radius ra.
%
% ELLIPSE(ra,rb,ang,x0,y0,C)
% adds ellipses of color C. C may be a string ('r','b',...) or the RGB value. 
% If no color is specified, it makes automatic use of the colors specified by 
% the axes ColorOrder property. For several circles C may be a vector.
%
% ELLIPSE(ra,rb,ang,x0,y0,C,Nb), Nb specifies the number of points
% used to draw the ellipse. The default value is 300. Nb may be used
% for each ellipse individually.
%
% h=ELLIPSE(...) returns the handles to the ellipses.
%
% as a sample of how ellipse works, the following produces a red ellipse
% tipped up at a 45 deg axis from the x axis
% ellipse(1,2,pi/8,1,1,'r')
%
% note that if ra=rb, ELLIPSE plots a circle
%

% written by D.G. Long, Brigham Young University, based on the
% CIRCLES.m original 
% written by Peter Blattner, Institute of Microtechnology, University of 
% Neuchatel, Switzerland, blattner@imt.unine.ch

% Check the number of input arguments 
if nargin<1,
    ra=[];
end
if nargin<2,
    rb=[];
end
if nargin<3,
    ang=[];
end

%if nargin==1,
%  error('Not enough arguments');
%end;

if nargin<5,
    x0=[];
    y0=[];
end
 
if nargin<6,
    C=[];
end

if nargin<7,
    Nb=[];
end

% set up the default values
if isempty(ra),ra=1;end;
if isempty(rb),rb=1;end;
if isempty(ang),ang=0;end;
if isempty(x0),x0=0;end;
if isempty(y0),y0=0;end;
if isempty(Nb),Nb=300;end;
if isempty(C),C=get(gca,'colororder');end;

% work on the variable sizes
x0=x0(:);
y0=y0(:);
ra=ra(:);
rb=rb(:);
ang=ang(:);
Nb=Nb(:);

if isstr(C),C=C(:);end;

if length(ra)~=length(rb),
    error('length(ra)~=length(rb)');
end
if length(x0)~=length(y0),
    error('length(x0)~=length(y0)');
end

% how many inscribed elllipses are plotted
if length(ra)~=length(x0)
    maxk=length(ra)*length(x0);
else
    maxk=length(ra);
end

% drawing loop
for k=1:maxk
    if length(x0)==1
        xpos=x0;
        ypos=y0;
        radm=ra(k);
        radn=rb(k);
        if length(ang)==1
            an=ang;
        else
            an=ang(k);
        end;
    elseif length(ra)==1
        xpos=x0(k);
        ypos=y0(k);
        radm=ra;
        radn=rb;
        an=ang;
    elseif length(x0)==length(ra)
        xpos=x0(k);
        ypos=y0(k);
        radm=ra(k);
        radn=rb(k);
        an=ang(k)
    else
        rada=ra(fix((k-1)/size(x0,1))+1);
        radb=rb(fix((k-1)/size(x0,1))+1);
        an=ang(fix((k-1)/size(x0,1))+1);
        xpos=x0(rem(k-1,size(x0,1))+1);
        ypos=y0(rem(k-1,size(y0,1))+1);
    end

    co=cos(an);
    si=sin(an);
    the=linspace(0,2*pi,Nb(rem(k-1,size(Nb,1))+1,:)+1);
%  x=radm*cos(the)*co-si*radn*sin(the)+xpos;
%  y=radm*cos(the)*si+co*radn*sin(the)+ypos;
%   h(k)=line(radm*cos(the)*co-si*radn*sin(the)+xpos,radm*cos(the)*si+co*ra
%   dn*sin(the)+ypos);
    h(k)=line(radm*cos(the)*co-si*radn*sin(the)+xpos,radm*cos(the)*si+co*radn*sin(the)+ypos,'linewidth',2);
    set(h(k),'color',C(rem(k-1,size(C,1))+1,:));
end

