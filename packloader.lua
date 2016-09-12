----------------------------------------------------------------------------
-- PACKLOADER loads packages, providing sample & get functions for training.
----------------------------------------------------------------------------

require 'os';
require 'sys';
require 'xlua';
require 'image';
require 'torch';
require 'paths';

torch.setdefaulttensortype('torch.FloatTensor')

local PackLoader = torch.class 'PackLoader'
local pathcat = paths.concat

function PackLoader:__init(opt)
    local check = argcheck{
        {name='directory', type='string', help='package directory', default='./package/'},
        {name='prefix', type='string', help='package prefix'},
        {name='batchsize', type='number', help='batch size'}
    }
    

    local meta = torch.load(pathcat(opt.directory, opt.prefix..'.t7'))
    self.prefix = meta.prefix
    self.packsize = meta.packsize
    self.N = meta.N
    self.imsize = meta.imsize
end

---------------------------------------------------
-- load a package
--
function PackLoader:__loadpackage(opt)
    local pidx = torch.random(self.N)   -- package index
    self.package = torch.load(pathcat('package', opt.prefix, 'part_'..pidx..'.t7'))
end

function PackLoader:sample(quantity)
    if not self.batchidx then self.batchidx = 1 end




end

function PackLoader:get(i1,i2)


end
