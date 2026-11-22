require "rake/testtask"
require "rake/extensiontask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("rdf-oxigraph.gemspec")

RbSys::ExtensionTask.new("rdf_oxigraph", GEMSPEC) do |ext|
  ext.lib_dir = "lib/rdf/oxigraph"
end

# Main suite: Minitest (matches solis-core).
Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
end
task test: :compile

# Conformance suite: rdf-spec shared examples (RSpec). Reports the rdf-spec
# baseline; ~19 expected failures are oxigraph typed-literal canonicalization
# (see README "Conformance & known deviations").
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:conformance) do |t|
    t.pattern = "spec/**/*_spec.rb"
  end
  task conformance: :compile
rescue LoadError
  desc "rdf-spec conformance (requires rspec + rdf-spec)"
  task :conformance do
    abort "rspec/rdf-spec not installed; run `bundle install`"
  end
end

task default: :test

# Interactive cross-compile helper. Drives rb-sys-dock to build precompiled
# native gems for a target you pick, looping until you quit.
#
# Two footguns it handles for you:
#   * Symlinked launch path. rb-sys-dock mounts the shell's $(pwd) (logical)
#     but runs the container in Ruby's resolved cwd (physical). If you reached
#     the project through a symlink (e.g. ~/Sources -> Dropbox/AllSources), the
#     container's working dir ends up empty ("No Rakefile found" / "Could not
#     locate Gemfile"). We force both to the real path before shelling out.
#   * Ruby 4.0 target. magnus 0.7 can't compile against the image's Ruby 4.0,
#     so we default to RUBY_VERSIONS "~> 3.0". Override via the env var if needed.
desc "Interactively cross-compile native gems via rb-sys-dock (loops until you quit)"
task :build do
  require "rb_sys/version"
  require "rb_sys/toolchain_info"

  real_root = __dir__
  launched = ENV["PWD"] || Dir.pwd
  unless launched == real_root
    note = ((File.realpath(launched) rescue nil) == real_root) ? "symlinked path" : "different directory"
    puts "⚠  Detected #{note}: #{launched}"
    puts "   Switching to the project's real path so the mount lines up: #{real_root}"
  end
  Dir.chdir(real_root)
  ENV["PWD"] = real_root

  ruby_versions = ENV.fetch("RUBY_VERSIONS", "~> 3.0")
  platforms = RbSys::ToolchainInfo.supported.map(&:platform).sort

  loop do
    puts
    puts "Cross-compile targets (Ruby #{ruby_versions}):"
    platforms.each_with_index { |p, i| puts format("  %2d) %s", i + 1, p) }
    puts "   q) quit"
    print "> Select a target to build: "
    $stdout.flush

    line = $stdin.gets
    break if line.nil? # Ctrl-D / EOF
    multi_sel = line.split(/,/).map(&:strip)

    break if multi_sel.empty? || multi_sel.map(&:downcase).include?('q')

    multi_sel.each do |sel|
      idx = Integer(sel, exception: false)
      platform =
        if idx && idx.between?(1, platforms.size)
          platforms[idx - 1]
        elsif platforms.include?(sel)
          sel
        end

      unless platform
        warn "  Invalid selection: #{sel.inspect}"
        next
      end

      cmd = ["bundle", "exec", "rb-sys-dock",
        "--platform", platform,
        "--ruby-versions", ruby_versions,
        "--build"]
      puts "\n\n\n→ #{cmd.join(" ")}"
      if system(*cmd)
        puts "✓ Built #{platform} — see pkg/ for the gem."
      else
        puts "✗ Build failed for #{platform} (exit #{$?.exitstatus})."
      end
    end
  end

  puts "Bye."
end
