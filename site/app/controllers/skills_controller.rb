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

  # The settled discovery convention (the agent-skills discovery RFC over RFC 8615,
  # schemas.agentskills.io/discovery/0.2.0): five fields per skill, and a
  # sha256 digest a conformant installer MUST verify. `npx skills add
  # <site-url>` installs from this document.
  def discovery
    render json: {
      "$schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
      skills: skill_sets.map { |name, files| discovery_entry(name, files) }
    }
  end

  def show
    content = skill_sets.dig(params[:skill], params[:file])
    raise ActionController::RoutingError, "unknown skill file" unless content

    render plain: content, content_type: "text/markdown"
  end

  # The archive payload a discovery entry's url points at: a flat tar.gz
  # built deterministically from the same file map, so the digest the
  # index advertised on one request matches the bytes this one serves.
  def archive
    files = skill_sets[params[:skill].to_s.delete_suffix(".tar.gz")]
    raise ActionController::RoutingError, "unknown skill" unless files

    send_data SkillArchive.build(files), filename: params[:skill], type: "application/gzip"
  end

  private

  # A lone SKILL.md is served as itself (type skill-md); anything more is
  # a flat tarball (type archive). Either way the digest is computed over
  # the exact bytes the url serves.
  def discovery_entry(name, files)
    single = files.keys == [ "SKILL.md" ]
    payload = single ? files["SKILL.md"] : SkillArchive.build(files)
    {
      name: name,
      description: frontmatter_description(files["SKILL.md"].to_s),
      type: single ? "skill-md" : "archive",
      url: "#{request.base_url}/.well-known/agent-skills/#{name}#{single ? '/SKILL.md' : '.tar.gz'}",
      digest: SkillArchive.digest(payload)
    }
  end

  def skill_sets
    @skill_sets ||= {
      "poetry" => Poetry::Ui.skill_files,
      "poetry-design" => design_skill_files,
      "poetry-docs-site" => site_skill_files
    }
  end

  def design_skill_files
    base = Poetry::Ui.root.join("lib/generators/poetry/skill/templates/poetry-design")
    Dir.glob("**/*.md", base: base).sort.to_h { |rel| [ rel, base.join(rel).read ] }
  end

  # The site-usage skill (S3 of the agent-legibility pass): how to navigate
  # THIS site as an agent - docs-app content, not gem content.
  def site_skill_files
    base = Rails.root.join("lib/skills/poetry-docs-site")
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
