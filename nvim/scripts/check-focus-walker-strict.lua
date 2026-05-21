local function hl(name)
	return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function assert_eq(label, expected, actual)
	if actual ~= expected then
		error(("%s expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
	end
end

package.loaded["focus-walker"] = nil
package.loaded["focus-walker.groups"] = nil
package.loaded["focus-walker.palette"] = nil
vim.cmd.colorscheme("focus-walker")

local normal = hl("Normal").fg
local comment = hl("Comment").fg
local string = hl("String").fg
local constant = hl("Constant").fg
local definition = hl("Function").fg

assert(comment ~= string, "Comment and string accents must be distinct")
assert(comment ~= constant, "Comment and constant accents must be distinct")
assert(comment ~= definition, "Comment and definition accents must be distinct")
assert(string ~= constant, "String and constant accents must be distinct")
assert(string ~= definition, "String and definition accents must be distinct")
assert(constant ~= definition, "Constant and definition accents must be distinct")

assert_eq("Comment uses the comment accent", comment, hl("@comment").fg)
assert_eq("String uses the string accent", string, hl("@string").fg)
assert_eq("Number uses the constant accent", constant, hl("@number").fg)
assert_eq("Boolean uses the constant accent", constant, hl("@boolean").fg)
assert_eq("Function calls use the definition accent", definition, hl("@function.call").fg)
assert_eq("Type definitions use the definition accent", definition, hl("@type.definition").fg)

assert_eq("Keywords stay normal", normal, hl("@keyword").fg)
assert_eq("Constructors stay normal", normal, hl("@constructor").fg)
assert_eq("Modules stay normal", normal, hl("@module").fg)
assert_eq("Macros stay normal", normal, hl("@constant.macro").fg)
assert_eq("Function macros stay normal", normal, hl("@function.macro").fg)
assert_eq("Tags stay normal", normal, hl("Tag").fg)
assert_eq("Special stays normal", normal, hl("Special").fg)
assert_eq("Builtin variables use the constant accent", constant, hl("@variable.builtin").fg)
assert_eq("Markup links use the definition accent", definition, hl("@markup.link").fg)

print("focus-walker strict syntax check passed")
