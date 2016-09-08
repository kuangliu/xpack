----------------------------------------------------------------------------
-- This module packs individual images into big continuous packages for
-- fast data accessing. Only image resizing is performed.
----------------------------------------------------------------------------

require 'xlua'
require 'image'
local argcheck = require 'argcheck'

local M = {}
local pathcat = paths.concat

--TODO: use charTensor to save space
torch.setdefaulttensortype('torch.FloatTensor')

------------------------------------------------------------------
-- pack images organized in subfolders, the subfolder name is the
-- class name.
--
function M.pack(opt)
    local check = argcheck{
        {name='directory', type='string', help='directory containing image folders'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000},
        {name='prefix', type='string', help='package saving as prefix_idx.t7'}
    }

    -- list all subfolders/classes
    local folders = sys.execute('ls -d '..opt.directory..'*/')
    local classes = string.split(folders, '\n')   -- split string to table

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

------------------------------------------------------------------
-- pack images based on a list file, containing image path and
-- targets separated by spaces.
--
function M.packlist(opt)
    local check = argcheck{
        {name='directory', type='string', help='image root directory'},
        {name='list', type='string', help='list file'},
        {name='imsize', type='number', help='image target size'},
        {name='packsize', type='number', help='# of images per package', default=10000},
        {name='prefix', type='string', help='package saving as prefix_idx.t7'}
    }

    -- shuffle list file
    print('==> shuffing list..')
    -- if it's macos, use gshuf from GNU coreutils
    local shuf = sys.uname()=='macos' and 'gshuf' or 'shuf'
    local shuffled = os.tmpname()
    os.execute(shuf..' '..opt.list..' > '..shuffled)
    local N = tonumber(sys.execute('wc -l < '..shuffled))

    -- parse name & targets line by line
    print('==> packing..')
    paths.mkdir('package')
    local images = torch.Tensor(opt.packsize, 3, opt.imsize, opt.imsize)
    local targets

    local f = assert(io.open(shuffled, 'r'))
    local i = 0
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
            images[ii] = image.scale(im, opt.imsize, opt.imsize)

            -- pack targets
            local target = {}
            for i = 2,#splited do
                target[#target+1] = tonumber(splited[i])
            end
            targets = targets or torch.Tensor(opt.packsize, #target)
            targets[ii] = torch.Tensor(target)

            if i % opt.packsize == 0 then
                -- save packages have packsize files
                pidx = (pidx or 0) + 1  -- package index
                local package = { X = images, Y = targets }
                torch.save('./package/'..opt.prefix..'_'..pidx..'.t7', package)
            elseif i == N then
                -- save the last package that has < packsize files
                local lastN = N % opt.packsize  -- # of files in the last package
                images = images[{ {1,lastN} }]
                targets = targets[{ {1,lastN} }]

                pidx = (pidx or 0) + 1
                local package = { X = images, Y = targets }
                torch.save('./package/'..opt.prefix..'_'..pidx..'.t7', package)
            end
        end
    end
    f:close()
    os.execute('rm -f '..shuffled)  -- clean up temporary file
    print('\n==> '..i..' files packed, '..(N-i)..' files ommited.')
end

return M
