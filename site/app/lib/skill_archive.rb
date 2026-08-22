# frozen_string_literal: true

require "digest"
require "stringio"
require "zlib"

# Deterministic flat tar.gz payloads for the agent-skills discovery index.
# The discovery RFC (schemas.agentskills.io/discovery/0.2.0) makes digest
# verification a MUST, so the sha256 the index advertises has to match the
# bytes any later request serves. Tar bakes in mtimes, owners, member
# order, and gzip its own timestamp - all pinned here (sorted members,
# mode 0644, owner 0/0, mtime 0, gzip mtime 0), so the same skill files
# always produce the same bytes and the digest can be computed from the
# one builder that also serves the payload.
class SkillArchive
  BLOCK = 512

  def self.build(files)
    tar = StringIO.new.binmode
    files.sort.each { |path, content| write_member(tar, path, content) }
    tar.write("\0" * (BLOCK * 2))
    gzip(tar.string)
  end

  def self.digest(bytes)
    "sha256:#{Digest::SHA256.hexdigest(bytes)}"
  end

  # A POSIX ustar file entry: 512-byte header + content padded to a block.
  # Members keep their relative paths (SKILL.md at the root - a wrapping
  # folder is the classic broken install; extractors create subdirs like
  # references/ from the member names alone).
  def self.write_member(tar, path, content)
    bytes = content.b
    tar.write(header_for(path, bytes.bytesize))
    tar.write(bytes)
    tar.write("\0" * (-bytes.bytesize % BLOCK))
  end

  def self.header_for(path, size)
    header = "".b
    header << path.ljust(100, "\0")               # name
    header << "0000644\0" << "0000000\0" << "0000000\0" # mode, uid, gid
    header << format("%011o\0", size)             # size
    header << format("%011o\0", 0)                # mtime, pinned
    header << " " * 8                             # chksum, spaces while summing
    header << "0"                                 # typeflag: regular file
    header << "\0" * 100                          # linkname
    header << "ustar\0" << "00"                   # magic, version
    header << "\0" * 32 << "\0" * 32              # uname, gname
    header << "0000000\0" << "0000000\0"          # devmajor, devminor
    header << "\0" * 155                          # prefix
    header = header.ljust(BLOCK, "\0")
    header[148, 8] = format("%06o\0 ", header.each_byte.sum)
    header
  end

  def self.gzip(bytes)
    io = StringIO.new.binmode
    writer = Zlib::GzipWriter.new(io)
    writer.mtime = 0
    writer.write(bytes)
    writer.close
    io.string
  end

  private_class_method :write_member, :header_for, :gzip
end
