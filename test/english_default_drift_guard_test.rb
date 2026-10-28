# frozen_string_literal: true

require "test_helper"
require "yaml"

# Production call sites for gem keys must not hand-copy English from en.yml as
# `default:`. English fallback comes from RecordingStudio.t / loaded :en.
#
# Scanner covers single-quoted, double-quoted, multi-line, paren-less,
# I18n.translate, constant, and Array defaults. Dynamic `default: label` for
# optional collection keys is allowed.
class EnglishDefaultDriftGuardTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCAN_GLOBS = %w[
    app/**/*.{rb,erb}
    lib/**/*.rb
  ].freeze
  SKIP_PATH_FRAGMENTS = %w[
    /generators/
  ].freeze

  TRANSLATION_CALL = /
    (?:
      RecordingStudio\.t |
      RecordingStudio::Translation\.t |
      I18n\.(?:t|translate) |
      \bt
    )
  /x

  def test_production_translation_calls_do_not_hand_copy_en_yml_english_defaults
    en_values = en_yml_leaf_values

    offenders = []
    scan_files.each do |path|
      source = File.read(path)
      source = strip_ruby_comments(source) if path.end_with?(".rb")

      each_translation_call(source) do |call_source|
        each_default_argument(call_source) do |default_src|
          next if allowed_dynamic_default?(default_src)

          values = default_values(default_src)
          values.each do |value|
            next unless en_values.include?(value)

            offenders << "#{relative(path)}: default: #{default_src} => #{value.inspect}"
          end
        end
      end
    end

    assert_empty offenders, <<~MSG
      Hand-copied English default:s drift from en.yml. Remove them and rely on
      RecordingStudio.t fallback instead.
      #{offenders.join("\n")}
    MSG
  end

  def test_scanner_catches_single_quoted_multiline_paren_less_translate_constant_and_array_defaults
    sample = <<~RUBY
      RecordingStudio.t("recording_studio.search.instant.placeholder", default: 'Try a name')
      RecordingStudio.t(
        "recording_studio.search.results.empty.title",
        default: "Type a little"
      )
      t "recording_studio.search.results.no_hits.title", default: "No luck"
      I18n.translate("recording_studio.search.results.columns.name", default: "Name")
      RecordingStudio.t("recording_studio.search.results.missing_detail", default: MISSING_DETAIL)
      RecordingStudio.t("recording_studio.search.results.empty.title", default: ["Type a little", "Other"])
      RecordingStudio.t "recording_studio.search.results.columns.detail", default: "Detail"
    RUBY

    en_values = en_yml_leaf_values
    constant_values = { "MISSING_DETAIL" => "—" }
    hits = []

    each_translation_call(sample) do |call_source|
      each_default_argument(call_source) do |default_src|
        hits.concat(
          default_values(default_src, constant_values).select { |value| en_values.include?(value) }
        )
      end
    end

    assert_includes hits, "Try a name"
    assert_includes hits, "Type a little"
    assert_includes hits, "No luck"
    assert_includes hits, "Name"
    assert_includes hits, "—"
    assert_includes hits, "Detail"
    assert_operator hits.count("Type a little"), :>=, 2, "array + multi-line Type a little"
  end

  def test_recording_studio_t_call_sites_only_use_this_gem_search_keys
    offenders = scan_files.flat_map { |path| recording_studio_t_offenders(path) }

    assert_empty offenders, <<~MSG
      RecordingStudio.t is only for this gem's shipped recording_studio.search.*
      keys. Host or other-namespace keys must stay on I18n.t / view t with main's
      default:.
      #{offenders.join("\n")}
    MSG
  end

  private

  def recording_studio_t_offenders(path)
    source = File.read(path)
    source = strip_ruby_comments(source) if path.end_with?(".rb")
    keys = source.scan(/RecordingStudio(?:::Translation)?\.t\(\s*["'](recording_studio\.[^"']+)["']/).flatten
    keys.reject { |key| key.start_with?("recording_studio.search.") }
        .map { |key| "#{relative(path)}: RecordingStudio.t(#{key.inspect})" }
  end

  def scan_files
    SCAN_GLOBS.flat_map { |glob| Dir[File.join(ROOT, glob)] }
              .uniq
              .reject { |path| SKIP_PATH_FRAGMENTS.any? { |frag| path.include?(frag) } }
  end

  def relative(path)
    path.delete_prefix("#{ROOT}/")
  end

  def en_yml_leaf_values
    tree = YAML.safe_load_file(File.join(ROOT, "config/locales/en.yml"), aliases: true)
               .fetch("en").fetch("recording_studio").fetch("search")
    flatten_values(tree).to_set
  end

  def flatten_values(node)
    case node
    when Hash then node.values.flat_map { |value| flatten_values(value) }
    when Array then node.flat_map { |value| flatten_values(value) }
    else [node]
    end
  end

  def strip_ruby_comments(source)
    source.gsub(/^\s*#.*$/, "")
  end

  def each_translation_call(source)
    index = 0
    while (match = source.match(TRANSLATION_CALL, index))
      start = match.end(0)
      call_body = extract_call_body(source, start, match[0])
      yield "#{match[0]}#{call_body}"
      index = start + 1
    end
  end

  def extract_call_body(source, start, method_name)
    return paren_body(source, start) if source[start] == "("
    if method_name.strip.match?(/\A(?:t|I18n\.(?:t|translate)|RecordingStudio\.t)\z/)
      return " #{slice_until_newline(source, start)}"
    end

    ""
  end

  def paren_body(source, open_index)
    depth = 0
    i = open_index
    while i < source.length
      case source[i]
      when "(" then depth += 1
      when ")"
        depth -= 1
        return source[open_index..i] if depth.zero?
      when "'", '"'
        i = skip_string(source, i)
        next
      end
      i += 1
    end
    source[open_index..]
  end

  def skip_string(source, index)
    quote = source[index]
    index += 1
    while index < source.length
      return index + 1 if source[index] == quote && source[index - 1] != "\\"

      index += 1
    end
    index
  end

  def slice_until_newline(source, start)
    line_end = source.index(/\n/, start) || source.length
    source[start...line_end]
  end

  def each_default_argument(call_source)
    offset = 0
    while (match = call_source.match(/default:\s*/, offset))
      value = read_ruby_expression(call_source, match.end(0))
      yield value.strip
      offset = match.end(0) + value.length
    end
  end

  def read_ruby_expression(source, start)
    i = skip_spaces(source, start)
    return "" if i >= source.length

    case source[i]
    when "'", '"'
      source[i...skip_string(source, i)]
    when "["
      read_bracketed_list(source, i)
    else
      finish = i
      finish += 1 while finish < source.length && source[finish].match?(/[A-Za-z0-9_:]/)
      source[i...finish]
    end
  end

  def skip_spaces(source, index)
    index += 1 while index < source.length && source[index].match?(/\s/)
    index
  end

  def read_bracketed_list(source, open_index)
    depth = 0
    index = open_index
    while index < source.length
      case source[index]
      when "[" then depth += 1
      when "]"
        depth -= 1
        return source[open_index..index] if depth.zero?
      when "'", '"'
        index = skip_string(source, index)
        next
      end
      index += 1
    end
    source[open_index..]
  end

  def allowed_dynamic_default?(default_src)
    normalized = default_src.gsub(/\s+/, "")
    %w[label].include?(normalized)
  end

  def default_values(default_src, constant_values = {})
    if string_literal_default?(default_src) || array_literal_default?(default_src)
      Array(YAML.safe_load(default_src, permitted_classes: [], aliases: false))
    elsif constant_default?(default_src)
      leaf = default_src.split("::").last
      Array(constant_values[default_src] || constant_values[leaf])
    else
      []
    end
  end

  def string_literal_default?(default_src)
    default_src.match?(/\A(['"]).*\1\z/m)
  end

  def array_literal_default?(default_src)
    default_src.start_with?("[")
  end

  def constant_default?(default_src)
    default_src.match?(/\A[A-Z][A-Za-z0-9_:]+\z/)
  end
end
