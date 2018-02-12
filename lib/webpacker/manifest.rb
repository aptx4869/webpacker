# Singleton registry for accessing the packs path using a generated manifest.
# This allows javascript_pack_tag, stylesheet_pack_tag, asset_pack_path to take a reference to,
# say, "calendar.js" or "calendar.css" and turn it into "/packs/calendar-1016838bab065ae1e314.js" or
# "/packs/calendar-1016838bab065ae1e314.css".
#
# When the configuration is set to on-demand compilation, with the `compile: true` option in
# the webpacker.yml file, any lookups will be preceeded by a compilation if one is needed.
class Webpacker::Manifest
  class MissingEntryError < StandardError; end

  attr_reader :variants
  delegate :config, :compiler, :dev_server, to: :@webpacker

  def initialize(webpacker)
    @webpacker = webpacker
    @data = {}
  end

  def refresh
    @data[variants] = load
  end

  def lookup(name, variants = [])
    @variants = variants
    compile if compiling?
    find name
  end

  def lookup!(name, variants = [])
    lookup(name, variants) || handle_missing_entry(name)
  end

  private

    def compiling?
      config.compile? && !dev_server.running?
    end

    def compile
      Webpacker.logger.tagged("Webpacker") { compiler.compile }
    end

    def find(name)
      data[name.to_s].presence
    end

    def handle_missing_entry(name)
      raise Webpacker::Manifest::MissingEntryError, missing_file_from_manifest_error(name)
    end

    def missing_file_from_manifest_error(bundle_name)
      <<-MSG
Webpacker can't find #{bundle_name} in #{public_manifest_path}. Possible causes:
1. You want to set webpacker.yml value of compile to true for your environment
   unless you are using the `webpack -w` or the webpack-dev-server.
2. webpack has not yet re-run to reflect updates.
3. You have misconfigured Webpacker's config/webpacker.yml file.
4. Your webpack configuration is not creating a manifest.
Your manifest contains:
#{JSON.pretty_generate(@data)}
      MSG
    end

    def data
      if config.cache_manifest?
        @data[variants] ||= load
      else
        refresh
      end
    end

    def public_manifest_path
      manifest = variants.blank? ? "manifest" : "manifest+#{variants.join}"
      config.public_output_path.join("#{manifest}.json")
    end

    def default_manifest_path
      config.public_manifest_path
    end

    def load
      manifest_path = public_manifest_path
      if manifest_path.exist?
        JSON.parse manifest_path.read
      elsif default_manifest_path.exist?
        JSON.parse default_manifest_path.read
      else
        {}
      end
    end
end
