local img_clip = {
	"HakonHarnes/img-clip.nvim",
	event = "VeryLazy",
	cmd = "PasteImage",
	keys = {
		{ "<leader>P", "<cmd>PasteImage<cr>", desc = "Paste clipboard image as path", mode = "n" },
	},
	opts = {
		default = {
			-- Save next to Pi's own clipboard pastes (Ctrl+V writes /tmp/pi-clipboard-*)
			dir_path = "/tmp",
			file_name = "pi-nvim-%Y%m%d-%H%M%S",
			extension = "png",

			-- Insert the bare absolute path, matching Pi's image-paste convention.
			-- Pi reads the editor text back literally; markdown wrappers would pollute the prompt.
			use_absolute_path = true,
			relative_to_current_file = false,
			template = "$FILE_PATH",
			url_encode_path = false,

			-- Skip the filename prompt for a fast one-keystroke paste
			prompt_for_file_name = false,
			show_dir_path_in_prompt = false,

			embed_image_as_base64 = false,
			copy_images = false,

			-- Dropping an image file into the buffer inserts its absolute path
			drag_and_drop = {
				enabled = true,
				insert_mode = false,
			},
		},
		-- Keep the bare path even in markdown buffers (Pi prompt.md, plain notes)
		filetypes = {
			markdown = {
				template = "$FILE_PATH",
				url_encode_path = false,
				use_absolute_path = true,
				prompt_for_file_name = false,
			},
		},
		-- Obsidian vault keeps the old behavior: relative vault assets + markdown link
		dirs = {
			["~/Research/Brain"] = {
				dir_path = "5-Achive/Assets",
				use_absolute_path = false,
				relative_to_current_file = true,
				url_encode_path = true,
				template = "![$CURSOR]($FILE_PATH)",
			},
		},
	},
}

return {
	img_clip,
}
