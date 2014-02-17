function pyra = featpyramid(im, model)
% Compute feature pyramid.
%
% pyra.feat{i} is the i-th level of the feature pyramid.
% pyra.scales{i} is the scaling factor used for the i-th level.
% pyra.feat{i+interval} is computed at exactly half the resolution of feat{i}.
% first octave halucinates higher resolution data.

sbin      = model.sbin;
interval  = model.interval;
padx      = max(model.maxsize(2)-1-1,0);
pady      = max(model.maxsize(1)-1-1,0);
sc = 2 ^(1/interval);
imsize = [size(im, 1) size(im, 2)];

limit = 0;
for i=1:length(model.filters)
	tmp_size = size(model.filters(i).w);
	tmp_size = tmp_size(1:2);
	limit = max(limit,max(tmp_size));
end
fprintf('[***DEBUG***] limit = %f\n', limit);

%max_scale = 1 + floor(log(min(imsize)/(5*sbin))/log(sc));
max_octave = floor(log(min(imsize)/sbin)) - 1;
max_scale = max_octave * interval;

pyra.feat = cell(max_scale,1);
pyra.scale = zeros(max_scale,1);

if size(im, 3) == 1
  im = repmat(im,[1 1 3]);
end
im = double(im); % our resize function wants floating point values

% for i = 1:interval
%   scaled = resize(im, 1/sc^(i-1));
%   pyra.feat{i} = features(scaled,sbin);
%   pyra.scale(i) = 1/sc^(i-1);
%   % remaining interals
%   for j = i+interval:interval:max_scale
%     scaled = reduce(scaled);
%     pyra.feat{j} = features(scaled,sbin);
%     pyra.scale(j) = 0.5 * pyra.scale(j-interval);
%   end
% end

scal = 1.0;
res_im = im;
flag = 0;
trunc = max_scale;
for oct = 1:max_octave
    for i = 1:interval
        pyra.feat{(oct-1)*interval + i} = features(res_im,sbin);
        pyra.scale((oct-1)*interval + i) = scal * 0.5^(oct-1);
        
        scal = 2^(-(i+1)/interval);
        res_im = resize(im,scal);

        [h,w] = size(res_im);
        h = max(floor(h/sbin)-2,0);
        w = max(floor(w/sbin)-2,0);
        if (h < limit || w < limit)
            fprintf('[***DEBUG***] flag is set!! w = %d, h = %d\n', w,h);
            flag = 1;
            trunc = (oct-1)*interval + i;
            break;
        end
    end
    if (flag)
      break;
    end
    im = res_im;
end

pyra.feat = pyra.feat(1:trunc,1);
pyra.scale = pyra.scale(1:trunc,1);

for i = 1:length(pyra.feat)
  % add 1 to padding because feature generation deletes a 1-cell
  % wide border around the feature map
  pyra.feat{i} = padarray(pyra.feat{i}, [pady+1 padx+1 0], 0);
  % write boundary occlusion feature
  pyra.feat{i}(1:pady+1, :, end) = 1;
  pyra.feat{i}(end-pady:end, :, end) = 1;
  pyra.feat{i}(:, 1:padx+1, end) = 1;
  pyra.feat{i}(:, end-padx:end, end) = 1;
end

pyra.scale    = model.sbin./pyra.scale;
pyra.interval = interval;
pyra.imy = imsize(1);
pyra.imx = imsize(2);
pyra.pady = pady;
pyra.padx = padx;
