----------------------------------------------------------------------------
-- PACKLOADER loads packages, providing sample & get functions for training.
----------------------------------------------------------------------------

require 'os';
require 'sys';
require 'xlua';
require 'image';
require 'torch';
require 'paths';
local argcheck = require 'argcheck'

torch.setdefaulttensortype('torch.FloatTensor')

local PackLoader = torch.class 'PackLoader'
local pathcat = paths.concat

function PackLoader:__init(opt)
    local check = argcheck{
        {name='directory', type='string', help='package directory', default='./package/'},
        {name='prefix', type='string', help='package prefix'},
        {name='packsize', type='number', help='# of images per package', default=10000}
    }
    self.directory, self.prefix, self.packsize = check(opt)
    -- # of packages
    self.npack = tonumber(sys.execute('ls '..pathcat(self.directory, self.prefix)..' | wc -l'))
    assert(self.npack > 0, 'No package found!')
end

---------------------------------------------------------------------------
-- shuffle the package loading order
--
function PackLoader:__shuffle()
    self.packorder = torch.randperm(self.npack)  -- package loading order
    self.packidx = 1                             -- reset package index
end

---------------------------------------------------------------------------
-- load the package indexed by self.packidx
--
function PackLoader:__loadpackage(quantity)
    local pidx = self.packorder[self.packidx]
    self.package = torch.load(pathcat(self.directory, self.prefix, 'part_'..pidx..'.t7'))

    -- shuffle batch order
    local N = self.package.X:size(1)
    self.batchorder = torch.randperm(N):long():split(quantity)
    self.batchorder[#self.batchorder] = nil
    self.batchidx = 1
end

---------------------------------------------------------------------------
-- randomly sample a batch of training data
--
function PackLoader:sample(quantity)
    -- reshuffle package order
    if not self.packorder or self.packidx > self.npack then
        self:__shuffle()
    end
    print(self.packorder[self.packidx], self.batchidx)

    -- load a package
    if not self.package or self.batchidx > #self.batchorder then
        self:__loadpackage(quantity)
        self.packidx = self.packidx + 1
    end

    local v = self.batchorder[self.batchidx]
    local images = self.package.X:index(1,v)
    local targets = self.package.Y:index(1,v)

    -- increase batchidx
    self.batchidx = self.batchidx + 1
    return images, targets
end

---------------------------------------------------------------------------
-- get samples in the range [i1, i2]
--
function PackLoader:get(i1,i2)
    local pidx1 = math.ceil(i1/self.packsize)  -- which package i1 belongs
    local pidx2 = math.ceil(i2/self.packsize)  -- which package i2 belongs

    local j1 = i1 % self.packsize  -- index within the package
    local j2 = i2 % self.packsize

    if self.packidx ~= pidx1 then
        self.packidx = pidx1
        self.package = torch.load(pathcat(self.directory, self.prefix, 'part_'..pidx1..'.t7'))
    end

    local images, targets

    if pidx1 == pidx2 then
        local indices = torch.range(j1,j2):long()
        images = self.package.X:index(1, indices)
        targets = self.package.Y:index(1, indices)
    else
        local N = self.package.X:size(1)
        local images1 = self.package.X[{ {j1, N} }]
        local targets1 = self.package.Y[{ {j1, N} }]

        self.packidx = pidx2
        self.package = torch.load(pathcat(self.directory, self.prefix, 'part_'..pidx2..'.t7'))
        local images2 = self.package.X[{ {1, j2} }]
        local targets2 = self.package.Y[{ {1, j2} }]

        -- concat them together
        images = torch.cat(images1, images2, 1)
        targets = torch.cat(targets1, targets2, 1)
    end

    return images, targets
end
