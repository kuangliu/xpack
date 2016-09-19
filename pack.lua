----------------------------------------------------------------------------
-- PACK packs individual images into big continuous packages for fast data
-- accessing. Only image resizing is performed.
----------------------------------------------------------------------------

require 'xlua'
require 'image'
local argcheck = require 'argcheck'

local M = {}
local pathcat = paths.concat

torch.setdefaulttensortype('torch.FloatTensor')

---------------------------------------------------------------------------
-- pack images organized in subfolders, the subfolder name is the
-- class name.
--
function M.pack(opt)
    local check = argcheck{
        pack=true,
        {name='directory', type='string', help='directory containing image folders'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000},
        {name='prefix', type='string', help='package saving as prefix_idx.t7'},
    }
    opt = check(opt)

    -- list all subfolders/classes
    local s = sys.execute('ls -d '..opt.directory..'*/')
    local classes = string.split(s, '\n')   -- split string to table

    -- loop each subfolder to collect images
    local pathfile = os.tmpname()   -- containing image paths
    local listfile = os.tmpname()   -- containing image paths and targets
    local catfile = os.tmpname()    -- concat different listfiles
    for i,class in pairs(classes) do
        print('==> parsing '..class)
        -- collect image path to pathfile
        os.execute('find '..class..' -name "*.jpg" > '..pathfile)
        -- attach class index to the end of each path
        os.execute('awk \'{print $0, "'..i..'"}\' '..pathfile..' > '..listfile)
        -- concat listfiles together
        os.execute('cat '..listfile..' >> '..catfile)
    end

    M.packlist{
        directory='',  -- as list contains complete path, so directory is empty
        list=catfile,
        imsize=opt.imsize,
        packsize=opt.packsize,
        prefix=opt.prefix
    }

    -- clean up temporary files
    os.execute('rm -f '..pathfile)
    os.execute('rm -f '..listfile)
    os.execute('rm -f '..catfile)
end

---------------------------------------------------------------------------
-- pack images based on a list file, containing image path and
-- targets separated by spaces.
--
function M.packlist(opt)
    local check = argcheck{
        pack=true,
        {name='directory', type='string', help='image root directory'},
        {name='list', type='string', help='list file'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000},
        {name='prefix', type='string', help='package saving as ./package/prefix/prefix_idx.t7'}
    }
    opt = check(opt)

    -- mkdir for package saving
    paths.mkdir('./package/'..opt.prefix)

    -- shuffle list file
    print('==> shuffling list..')
    -- if it's macos, use gshuf from GNU coreutils
    local shuf = sys.uname()=='macos' and 'gshuf' or 'shuf'
    local shuffled = os.tmpname()
    os.execute(shuf..' '..opt.list..' > '..shuffled)
    local N = tonumber(sys.execute('wc -l < '..shuffled))

    -- parse name & targets line by line
    print('==> packing..')
    -- use ByteTensor instead of FloatTensor to cut the space usage
    local images = torch.ByteTensor(opt.packsize, 3, opt.imsize, opt.imsize)
    local targets

    local f = assert(io.open(shuffled, 'r'))
    local i = 0     -- file index
    local pidx = 0  -- package index
    while true do
        local line = f:read('*l')
        if not line then break end

        local splited = string.split(line, '%s+')
        local ok, im = pcall(image.load, pathcat(opt.directory, splited[1]))
        if ok then
            i = i + 1
            xlua.progress(i,N)

            -- pack images
            local ii = 1 + (i-1) % opt.packsize  -- index within a package
            images[ii]:copy(image.scale(im, opt.imsize, opt.imsize):mul(255))

            -- pack targets
            local target = {}
            for i = 2,#splited do
                target[#target+1] = tonumber(splited[i])
            end
            targets = targets or torch.Tensor(opt.packsize, #target)
            targets[ii] = torch.Tensor(target)

            if i % opt.packsize == 0 then
                -- save packages have packsize files
                pidx = pidx + 1
                local package = { X=images, Y=targets }
                torch.save(pathcat('package', opt.prefix, 'part_'..pidx..'.t7'), package)
            elseif i == N then
                -- save the last package that has < packsize files
                local lastN = N % opt.packsize  -- # of files in the last package
                images = images[{ {1,lastN} }]
                targets = targets[{ {1,lastN} }]

                pidx = pidx + 1
                local package = { X=images, Y=targets }
                torch.save(pathcat('package', opt.prefix, 'part_'..pidx..'.t7'), package)
            end
        end
    end
    f:close()
    print('\n==> '..i..' files packed, '..(N-i)..' files ommitted.')

    -- save some package info
    torch.save(pathcat('package', opt.prefix..'.t7'), {
        N=i,
        imsize=opt.imsize,
        packsize=opt.packsize,
        prefix=opt.prefix,
        list=shuffled
    })
end

---------------------------------------------------------------------------
-- split images of each class into train/val/test categories.
-- it returns a table containing list files of each category.
--
function M.__split(opt)
    local check = argcheck{
        pack=true,
        {name='directory', type='string', help='directory containing image folders'},
        {name='partition', type='table', help='partition ratio e.g. { train=0.8, val=0.2 }'},
    }
    opt = check(opt)

    -- return a table containing splited lists
    local lists = {}
    for k,_ in pairs(opt.partition) do
        lists[k] = os.tmpname()
    end

    -- list all subfolders/classes
    local s = sys.execute('ls -d '..opt.directory..'*/')
    local classes = string.split(s, '\n')   -- split string to table

    -- loop each subfolder to collect images
    local pathfile = os.tmpname()   -- containing image paths
    local listfile = os.tmpname()   -- containing image paths and targets
    for i,class in pairs(classes) do
        print('==> parsing '..class)
        -- collect image path to pathfile
        os.execute('find '..class..' -name "*.jpg" > '..pathfile)
        -- attach class index to the end of each path
        os.execute('awk \'{print $0, "'..i..'"}\' '..pathfile..' > '..listfile)
        -- split listfile into categories
        local nlines = tonumber(sys.execute('wc -l < '..listfile))
        local i1 = 0      -- start index
        local i2 = 0      -- end index
        local acc = 0     -- accumulated ratio
        for k,v in pairs(opt.partition) do
            acc = acc + v
            i1 = i2 + 1
            i2 = math.ceil(nlines*acc)
            -- split listfile lines between [i1, i2] into lists[k]
            os.execute('head -n '..i2..' '..listfile..' | tail -n +'..i1..' >> '..lists[k])
        end
    end
    return lists
end

---------------------------------------------------------------------------
-- first split images into train/val/test, and pack them respectively.
--
function M.packsplit(opt)
    local check = argcheck{
        pack=true,
        {name='directory', type='string', help='directory containing image folders'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000},
        {name='partition', type='table', help='partition ratio e.g. { train=0.8, val=0.2 }'}
    }
    opt = check(opt)

    -- get splited lists
    local lists = M.__split{
        directory=opt.directory,
        partition=opt.partition
    }
    print(lists)

    -- pack each category
    for prefix,list in pairs(lists) do
        M.packlist{
            directory='',
            list=list,
            imsize=opt.imsize,
            packsize=opt.packsize,
            prefix=prefix
        }
    end
end

return M
