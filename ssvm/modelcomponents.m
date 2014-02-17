function [components,filters,resp] = modelcomponents(model,pyra)
% Cache various statistics from the model data structure for later use  
components = cell(length(model.components),1);
for c = 1:length(model.components)
	for k = 1:length(model.components{c})
		p = model.components{c}(k); % part k at component c
		[p.sizy,p.sizx,p.w,p.biasI,p.filterI,p.defI,p.starty,p.startx,p.step,p.level,p.Ix,p.Iy] = deal([]);
		[p.scale,p.level,p.Ix,p.Iy] = deal(0);

		% store the scale of each part relative to the component root
		par = p.parent;      
		assert(par < k);
		p.b = [model.bias(p.biasid).w];
		p.b = reshape(p.b,[1 size(p.biasid)]);
		p.biasI = [model.bias(p.biasid).i];
		p.biasI = reshape(p.biasI,size(p.biasid));
		
		for f = 1:length(p.filterid)
			x = model.filters(p.filterid(f));
			[p.sizy(f) p.sizx(f) foo] = size(x.w);
			p.filterI(f) = x.i;
		end
		
		for f = 1:length(p.defid)	  
			x = model.defs(p.defid(f));
			p.w(:,f)  = x.w';
			p.defI(f) = x.i;
			ax = x.anchor(1);
			ay = x.anchor(2);    
			ds = x.anchor(3);
			p.scale = ds + components{c}(par).scale;
			% amount of (virtual) padding to hallucinate
			step = 2^ds;
			virtpady = (step-1)*pyra.pady;
			virtpadx = (step-1)*pyra.padx;
			% starting points (simulates additional padding at finer scales)
			p.starty(f) = ay-virtpady;
			p.startx(f) = ax-virtpadx;      
			p.step   = step;
		end
		components{c}(k) = p;
	end
end

if ~isstruct(pyra)
  resp = cell(1,1);
  filters = cell(1,1);
  filters{1} = model.filters(1).w;
  return
end
  
resp    = cell(length(pyra.feat),1);
filters = cell(length(model.filters),1);
for i = 1:length(filters)
	filters{i} = model.filters(i).w;
end
