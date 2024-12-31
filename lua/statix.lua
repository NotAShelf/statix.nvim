local M = {}

-- Default configuration
M.config = {
    statix_binary = "statix", -- Path to the statix binary
    auto_check = true,        -- Automatically lint on save
    keymap = "<Leader>ls",    -- Keymap for applying suggestions
}

function M.setup(user_config)
    M.config = vim.tbl_extend("force", M.config, user_config or {})
end

function M.apply_suggestion()
    local line = vim.fn.line('.')
    local col = vim.fn.col('.')
    local file = vim.fn.expand('%')
    local cmd = string.format("%s single -p %d,%d %s", M.config.statix_binary, line, col, file)

    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        vim.api.nvim_command("undo")
        vim.notify("Statix suggestion failed. Shell returned: " .. vim.v.shell_error, vim.log.levels.ERROR)
        vim.notify(output, vim.log.levels.ERROR)
    elseif output:match("nothing to fix") then
        vim.notify("No fixes available at the cursor position.", vim.log.levels.INFO)
    else
        -- Apply the changes only if the output is valid
        vim.api.nvim_command(string.format(":%s%%!%s", vim.fn.bufnr('%'), cmd))
    end

    -- Restore the cursor position
    vim.api.nvim_win_set_cursor(0, { line, col })
end

local function run_statix_check()
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    if file_path == "" then return end -- skip unsaved

    vim.fn.jobstart({ M.config.statix_binary, "check", "-o", "errfmt", file_path }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                -- Add errors to the quickfix list
                vim.fn.setqflist({}, "r", {
                    title = "Statix Lint",
                    lines = data,
                    efm = "%f>%l:%c:%t:%n:%m",
                })
                vim.api.nvim_command("cwindow")
            end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify("Statix linting failed", vim.log.levels.ERROR)
            end
        end,
    })
end

local function setup_autocmds()
    local group = vim.api.nvim_create_augroup("StatixCheck", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "*.nix",
        callback = function()
            vim.opt_local.errorformat = "%f>%l:%c:%t:%n:%m"
        end,
        group = group,
    })

    if M.config.auto_check then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = "*.nix",
            callback = run_statix_check,
            group = group,
        })
    end
end

function M.init()
    setup_autocmds()
end

return M
