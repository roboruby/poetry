# frozen_string_literal: true

# The web-installable Agent Skills surface: the files-roster
# inventory + per-file serving at /.well-known/skills, the discovery
# document at /.well-known/agent-skills, and the payload routes under
# /agent-skills. Everything projects from SkillCatalog, so no surface can
# drift from what `bin/rails g poetry:skill` installs. Lookups go through
# an in-memory file map only (traversal-safe by construction).
class SkillsController < ApplicationController
  def index
    render json: { skills: skill_sets.map { |name, files| index_entry(name, files) } }
  end

  # The settled discovery convention (the agent-skills discovery RFC over RFC 8615,
  # schemas.agentskills.io/discovery/0.2.0): five fields per skill, and a
  # sha256 digest a conformant installer MUST verify. `npx skills add
  # <site-url>/agent-skills` installs from this document.
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

  def skill_sets
    @skill_sets ||= SkillCatalog.sets
  end

  def discovery_entry(name, files)
    single = SkillCatalog.single_file?(files)
    payload = single ? files["SKILL.md"] : SkillArchive.build(files)
    {
      name: name,
      description: SkillCatalog.description(files),
      type: single ? "skill-md" : "archive",
      url: "#{request.base_url}#{SkillCatalog.payload_path(name, files)}",
      digest: SkillArchive.digest(payload)
    }
  end

  def index_entry(name, files)
    {
      name: name,
      description: SkillCatalog.description(files),
      files: files.keys.sort
    }
  end
end
