#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "464db78f0707d22a43f7bf2c74cc0c52beff59b0f58535d1eb64f3c680dc889c", "source_sha256": "a1a384d35f3380f69c57a009348f8a076cc5e3fc09ba866cde4cf59a1c6ac88b", "target_language": "ruby"}
# arg-utils.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/arg-utils.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

module ArgUtils
  def self.read_env_number(name, env = ENV)
    raw = env[name]&.strip
    return nil if raw.nil? || raw.empty?

    parsed = Float(raw) rescue nil
    parsed&.finite? ? parsed : nil
  end

  def self.consume_string_flag(argv, index, flag, current_value)
    return nil unless argv[index] == flag

    {
      next_index: index + 1,
      value: index + 1 < argv.length ? argv[index + 1] : current_value
    }
  end

  def self.consume_string_list_flag(argv, index, flag)
    return nil unless argv[index] == flag

    value = index + 1 < argv.length ? argv[index + 1] : nil
    {
      next_index: index + 1,
      value: value.is_a?(String) && !value.empty? ? value : nil
    }
  end

  def self.consume_int_flag(argv, index, flag, current_value, options = {})
    return nil unless argv[index] == flag

    raw_value = index + 1 < argv.length ? argv[index + 1] : ""
    parsed = Integer(raw_value) rescue nil
    min = options[:min] || -Float::INFINITY

    value = (parsed.is_a?(Integer) && parsed >= min) ? parsed : current_value
    {
      next_index: index + 1,
      value: value
    }
  end

  def self.consume_float_flag(argv, index, flag, current_value, options = {})
    return nil unless argv[index] == flag

    raw_value = index + 1 < argv.length ? argv[index + 1] : ""
    parsed = Float(raw_value) rescue nil
    min = options[:min] || -Float::INFINITY
    include_min = options.fetch(:include_min, true)

    is_valid = parsed.is_a?(Float) && parsed.finite?
    is_valid &&= include_min ? parsed >= min : parsed > min

    value = is_valid ? parsed : current_value
    {
      next_index: index + 1,
      value: value
    }
  end

  def self.string_flag(flag, key)
    {
      consume: ->(argv, index, args) {
        option = consume_string_flag(argv, index, flag, args[key])
        return nil unless option

        {
          next_index: option[:next_index],
          apply: ->(target) { target[key] = option[:value] }
        }
      }
    }
  end

  def self.string_list_flag(flag, key)
    {
      consume: ->(argv, index, _args) {
        option = consume_string_list_flag(argv, index, flag)
        return nil unless option

        {
          next_index: option[:next_index],
          apply: ->(target) { 
            target[key] << option[:value] if option[:value]
          }
        }
      }
    }
  end

  def self.create_assigned_value_flag(consume_option)
    {
      consume: ->(argv, index, args) {
        option = consume_option.call(argv, index, args)
        return nil unless option

        {
          next_index: option[:next_index],
          apply: ->(target) { target[option[:key]] = option[:value] }
        }
      }
    }
  end

  def self.int_flag(flag, key, options = {})
    create_assigned_value_flag(
      ->(argv, index, args) {
        option = consume_int_flag(argv, index, flag, args[key], options)
        option ? option.merge(key: key) : nil
      }
    )
  end

  def self.float_flag(flag, key, options = {})
    create_assigned_value_flag(
      ->(argv, index, args) {
        option = consume_float_flag(argv, index, flag, args[key], options)
        option ? option.merge(key: key) : nil
      }
    )
  end

  def self.boolean_flag(flag, key, value = true)
    {
      consume: ->(argv, index, _args) {
        return nil unless argv[index] == flag

        {
          next_index: index,
          apply: ->(target) { target[key] = value }
        }
      }
    }
  end

  def self.parse_flag_args(argv, args, specs, options = {})
    i = 0
    while i < argv.length
      arg = argv[i]

      if arg == "--" && options[:ignore_double_dash]
        i += 1
        next
      end

      handled = false
      specs.each do |spec|
        option = spec[:consume].call(argv, i, args)
        next unless option

        option[:apply].call(args)
        i = option[:next_index]
        handled = true
        break
      end

      if handled
        i += 1
        next
      end

      fallback_result = options[:on_unhandled_arg]&.call(arg, args)
      if fallback_result == "handled"
        i += 1
        next
      end

      if !options[:allow_unknown_options] && arg.start_with?("-")
        raise "Unknown option: #{arg}"
      end

      i += 1
    end

    args
  end
end
