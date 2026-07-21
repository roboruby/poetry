# The web-installable Agent Skills surface (, the react-aria
# .well-known/skills parity): index.json for discovery + every skill file
# served under .well-known/skills/<name>/<path>. Content comes from the
# same generators the installed skills use - the usage skill live from the
# registry, poetry-design from the gem's curated templates - so this
# surface can never drift from what `bin/rails g poetry:skill` installs.
# Lookups go through an in-memory file map only (traversal-safe by
# construction).
class SkillsController < ApplicationController
  def index
    render json: { skills: skill_sets.map { |name, files| index_entry(name, files) } }
  end

  def show
    content = skill_sets.dig(params[:skill], params[:file])
    raise ActionController::RoutingError, "unknown skill file" unless content

    render plain: content, content_type: "text/markdown"
  end

  private

  def skill_sets
    @skill_sets ||= {
      "poetry" => Poetry::Ui.skill_files,
      "poetry-design" => design_skill_files
    }
  end

  def design_skill_files
    base = Poetry::Ui.root.join("lib/generators/poetry/skill/templates/poetry-design")
    Dir.glob("**/*.md", base: base).sort.to_h { |rel| [ rel, base.join(rel).read ] }
  end

  def index_entry(name, files)
    {
      name: name,
      description: frontmatter_description(files["SKILL.md"].to_s),
      files: files.keys.sort
    }
  end

  # The SKILL.md frontmatter description (folded-scalar tolerant).
  def frontmatter_description(skill_md)
    frontmatter = skill_md[/\A---\n(.*?)\n---/m, 1].to_s
    folded = frontmatter[/^description: >-\n((?:[ ]{2,}.*\n?)+)/, 1]
    return folded.split("\n").map(&:strip).join(" ").strip if folded

    frontmatter[/^description:[ ]*(.+)$/, 1].to_s.strip
  end
end
