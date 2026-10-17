# Erzeugt von matugen (templates/tide-colors.fish) – hier nichts ändern.
# Tide ruhig wie die Leiste: Pfad in Schrifttönen, alles Übrige blass, die
# Akzentfarbe nur für ❯. theme.sh führt die Datei aus; die Universal-
# Variablen gelten sofort in allen offenen Shells (conf.d/matugen-tide.fish).
set -l fg {{colors.on_surface.default.hex_stripped}}
set -l dim {{colors.on_surface_variant.default.hex_stripped}}
set -l faint {{colors.outline.default.hex_stripped}}
set -l line {{colors.outline_variant.default.hex_stripped}}
set -l accent {{colors.primary.default.hex_stripped}}
set -l soft {{colors.tertiary.default.hex_stripped}}
set -l err {{colors.error.default.hex_stripped}}

set -U tide_pwd_color_anchors $fg
set -U tide_pwd_color_dirs $dim
set -U tide_pwd_color_truncated_dirs $faint

set -U tide_git_color_branch $faint
set -U tide_git_color_upstream $faint
set -U tide_git_color_stash $faint
set -U tide_git_color_dirty $soft
set -U tide_git_color_staged $soft
set -U tide_git_color_untracked $soft
set -U tide_git_color_conflicted $err
set -U tide_git_color_operation $err

set -U tide_character_color $accent
set -U tide_character_color_failure $err

set -U tide_status_color $faint
set -U tide_status_color_failure $err
set -U tide_time_color $faint
set -U tide_cmd_duration_color $faint
set -U tide_context_color_default $faint
set -U tide_context_color_ssh $faint
set -U tide_context_color_root $err
set -U tide_jobs_color $faint
set -U tide_prompt_color_frame_and_connection $line
set -U tide_prompt_color_separator_same_color $line

for v in tide_vi_mode_color_{default,insert,replace,visual}
    set -U $v $faint
end
# Sprachen und Werkzeuge rechts (node, python, go …)
for item in direnv bun node python rustc java php pulumi ruby go gcloud kubectl distrobox toolbox terraform aws nix_shell crystal elixir zig docker
    set -q tide_{$item}_color && set -U tide_{$item}_color $faint
end
