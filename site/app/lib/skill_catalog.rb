# frozen_string_literal: true

# The one source every skills surface projects from: the machine index
# and discovery document, the payload routes, and the human catalog page
# all read this same map, so none of them can drift from what
# `bin/rails g poetry:skill` installs. Content comes from the same
# generators the installed skills use - the usage skill live from the
# registry, poetry-design from the gem's curated templates, the site
# skill from this app.
#
# @example Every installable skill set, name => { relative path => content }
#   SkillCatalog.sets
class SkillCatalog
  def self.sets
    {
      "poetry" => Poetry::Ui.skill_files,
      "poetry-design" => design_skill_files,
      "poetry-component" => component_skill_files,
      "poetry-docs-site" => site_skill_files
    }
  end

  # A lone SKILL.md is served as itself (discovery type skill-md);
  # anything more ships as a flat tarball (type archive).
  def self.single_file?(files)
    files.keys == [ "SKILL.md" ]
  end

  # The payload path a discovery entry's url (and the catalog page's curl
  # command) points at, under the /agent-skills prefix so installers that
  # scope by path find every entry.
  def self.payload_path(name, files)
    single_file?(files) ? "/agent-skills/#{name}/SKILL.md" : "/agent-skills/#{name}.tar.gz"
  end

  # The SKILL.md frontmatter description (folded-scalar tolerant).
  def self.description(files)
    frontmatter = files["SKILL.md"].to_s[/\A---\n(.*?)\n---/m, 1].to_s
    folded = frontmatter[/^description: >-\n((?:[ ]{2,}.*\n?)+)/, 1]
    return folded.split("\n").map(&:strip).join(" ").strip if folded

    frontmatter[/^description:[ ]*(.+)$/, 1].to_s.strip
  end

  def self.design_skill_files
    gem_template_files("poetry-design")
  end

  def self.component_skill_files
    gem_template_files("poetry-component")
  end

  def self.gem_template_files(skill)
    base = Poetry::Ui.root.join("lib/generators/poetry/skill/templates", skill)
    Dir.glob("**/*.md", base: base).sort.to_h { |rel| [ rel, base.join(rel).read ] }
  end

  # The site-usage skill: how to navigate THIS site as an agent -
  # docs-app content, not gem content.
  def self.site_skill_files
    base = Rails.root.join("lib/skills/poetry-docs-site")
    Dir.glob("**/*.md", base: base).sort.to_h { |rel| [ rel, base.join(rel).read ] }
  end

  private_class_method :design_skill_files, :component_skill_files,
                       :gem_template_files, :site_skill_files
end
