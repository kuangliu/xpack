----------------------------------------------------------------------------
-- PACKLOADER loads packages, providing sample & get functions for training.
----------------------------------------------------------------------------

require 'os'
require 'sys'
require 'xlua'
require 'image'
require 'torch'
require 'paths'
local argcheck = require 'argcheck'

torch.setdefaulttensortype('torch.FloatTensor')

local PackLoader = torch.class 'PackLoader'
local pathcat = paths.concat

function PackLoader:__init(opt)
    local check = argcheck{
        {name='directory', type='string', help='package directory'},
        {name='prefix', type='string', help='package prefix'}
    }
    self.directory, self.prefix = check(opt)

    -- parse package info
    local info = torch.load(pathcat(self.directory, self.prefix..'.t7'))
    self.N = info.N
    self.packsize = info.packsize

    -- # of packages
    self.npack = tonumber(sys.execute('ls '..pathcat(self.directory, self.prefix)..' | wc -l'))
    assert(self.npack > 0, 'No package found!')
    assert(self.npack == math.ceil(self.N/self.packsize), 'Check the # of packages!')
end

---------------------------------------------------------------------------
-- shuffle the package loading order
--
function PackLoader:__shufflePack()
    self.packorder = torch.randperm(self.npack)  -- package loading order
    self.packidx = 1                             -- reset package index
end

---------------------------------------------------------------------------
-- shuffle the batch loading order
--
function PackLoader:__shuffleBatch(quantity)
    -- shuffle batch order
    local N = self.package.X:size(1)
    assert(quantity <= N, 'quantity is too large!')
    self.batchorder = torch.randperm(N):long():split(quantity)
    if self.batchorder[#self.batchorder]:numel() ~= quantity then
        self.batchorder[#self.batchorder] = nil
    end
    self.batchidx = 1
end

---------------------------------------------------------------------------
-- load the package indexed by self.packidx
--
function PackLoader:__loadPackage()
    local pidx = self.packorder[self.packidx]
    self.package = torch.load(pathcat(self.directory, self.prefix, 'part_'..pidx..'.t7'))
    self.package.X = self.package.X:float():div(255)  -- convert to FloatTensor
end

---------------------------------------------------------------------------
-- randomly sample a batch of training data
--
function PackLoader:sample(quantity)
    -- shuffle package order
    if not self.packorder or self.packidx > self.npack then
        self:__shufflePack()
    end

    -- load a new package
    if not self.package or self.batchidx > #self.batchorder then
        self:__loadPackage()
        self:__shuffleBatch(quantity)
        self.packidx = self.packidx + 1
    end

    -- shuffle batch order
    if self.batchorder[self.batchidx]:numel() ~= quantity then
        self:__shuffleBatch(quantity)
    end

    -- get the batch indices
    local v = self.batchorder[self.batchidx]
    local images = self.package.X:index(1,v)
    local targets = self.package.Y:index(1,v)

    self.batchidx = self.batchidx + 1  -- increase batchidx
    return images, targets
end

---------------------------------------------------------------------------
-- get samples in the range [i1, i2]
--
function PackLoader:get(i1,i2)
    local pidx1 = math.ceil(i1/self.packsize)  -- which package i1 belongs
    local pidx2 = math.ceil(i2/self.packsize)  -- which package i2 belongs

    local j1 = (i1 - 1) % self.packsize + 1    -- index within the package
    local j2 = (i2 - 1) % self.packsize + 1

    if self.packidx ~= pidx1 then
        self.packidx = pidx1
        self.package = torch.load(pathcat(self.directory, self.prefix, 'part_'..pidx1..'.t7'))
    end

    local images, targets

    if pidx1 == pidx2 then
        local v = torch.range(j1,j2):long()
        images = self.package.X:index(1,v)
        targets = self.package.Y:index(1,v)
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

    return images:float():div(255), targets
end
