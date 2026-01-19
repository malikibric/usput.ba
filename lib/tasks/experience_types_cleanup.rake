# frozen_string_literal: true

namespace :experience_types do
  desc "Clean up duplicate and typo experience types"
  task cleanup_duplicates: :environment do
    puts "🧹 Cleaning up duplicate and typo experience types..."
    puts ""

    # Define mappings: duplicate_key => canonical_key
    duplicates = {
      "cuisine" => "food",
      "culinary" => "local-cuisine",
      "cultural-exploration" => "culture",
      "historical" => "history",
      "scape-view" => "scenic-view"
    }

    # Typos to delete (no mappings)
    typos = %w[cultre]

    total_moved = 0
    total_deleted = 0

    # Process duplicates (move locations to canonical type)
    duplicates.each do |duplicate_key, canonical_key|
      duplicate_type = ExperienceType.find_by(key: duplicate_key)
      canonical_type = ExperienceType.find_by(key: canonical_key)

      unless duplicate_type && canonical_type
        puts "⚠️  Skipping #{duplicate_key} → #{canonical_key}: types not found"
        next
      end

      locations_count = duplicate_type.locations.count
      if locations_count.zero?
        puts "✓ #{duplicate_key}: No locations to move"
        duplicate_type.destroy
        total_deleted += 1
        next
      end

      puts "→ Moving #{locations_count} locations from '#{duplicate_key}' to '#{canonical_key}'"

      # Move all locations from duplicate to canonical
      duplicate_type.locations.find_each do |location|
        # Check if location already has canonical type
        unless location.location_experience_types.exists?(experience_type: canonical_type)
          location.location_experience_types.create!(experience_type: canonical_type)
          total_moved += 1
        end

        # Remove duplicate type
        location.location_experience_types.find_by(experience_type: duplicate_type)&.destroy
      end

      # Delete the duplicate type
      duplicate_type.reload
      duplicate_type.destroy
      puts "  ✓ Deleted '#{duplicate_key}' type"
      total_deleted += 1
    end

    # Process typos (just delete)
    typos.each do |typo_key|
      typo_type = ExperienceType.find_by(key: typo_key)
      next unless typo_type

      locations_count = typo_type.locations.count
      if locations_count > 0
        puts "⚠️  Typo '#{typo_key}' has #{locations_count} locations - review manually"
      else
        typo_type.destroy
        puts "✓ Deleted typo '#{typo_key}'"
        total_deleted += 1
      end
    end

    puts ""
    puts "📊 Summary:"
    puts "  - Locations moved: #{total_moved}"
    puts "  - Types deleted: #{total_deleted}"
    puts ""
    puts "✅ Cleanup complete!"
  end

  desc "Show experience types statistics"
  task stats: :environment do
    puts ""
    puts "📊 Experience Types Statistics"
    puts "=" * 60
    puts ""

    total_types = ExperienceType.count
    active_types = ExperienceType.active.count

    puts "Total types: #{total_types} (#{active_types} active)"
    puts ""

    puts "Usage breakdown:"
    ExperienceType.left_joins(:locations)
      .group("experience_types.id", "experience_types.key", "experience_types.name")
      .select("experience_types.*, COUNT(locations.id) as locations_count")
      .order("COUNT(locations.id) DESC, experience_types.name ASC")
      .each do |et|
        loc_count = et.locations_count.to_i
        status = loc_count.zero? ? "❌ UNUSED" : "✓"
        puts "  #{status} #{et.key.ljust(25)} (#{et.name}): #{loc_count} locations"
      end

    puts ""
    puts "=" * 60

    # Check for potential duplicates
    puts ""
    puts "Potential duplicates (similar names):"
    potential_dupes = ExperienceType.all.group_by { |et| et.key.gsub(/[-_]/, "").gsub(/s$/, "") }
      .select { |_base, types| types.count > 1 }

    if potential_dupes.any?
      potential_dupes.each do |base, types|
        puts "  - Similar to '#{base}': #{types.map(&:key).join(', ')}"
      end
    else
      puts "  ✓ No potential duplicates found"
    end
  end

  desc "Retroactively populate experience types for locations without types"
  task populate_missing: :environment do
    puts "🔄 Populating experience types for locations without types..."
    puts ""

    classifier = Ai::ExperienceTypeClassifier.new

    # Get count first
    locations_without_types = Location.left_joins(:location_experience_types)
      .where(location_experience_types: { id: nil })
      .distinct

    total = locations_without_types.count
    puts "Found #{total} locations without experience types"
    puts ""

    # Ask for confirmation (skip if AUTO_CONFIRM=true)
    unless ENV["AUTO_CONFIRM"] == "true"
      print "Continue? (y/N): "
      response = STDIN.gets.chomp.downcase
      unless response == "y"
        puts "Cancelled"
        exit
      end
    else
      puts "Auto-confirming (AUTO_CONFIRM=true)"
    end

    # Process in batches
    result = classifier.classify_missing(dry_run: false)

    puts ""
    puts "📊 Results:"
    puts "  - Total: #{result[:total]}"
    puts "  - Successful: #{result[:successful]}"
    puts "  - Failed: #{result[:failed]}"
    puts ""

    if result[:types_added].any?
      puts "Types added:"
      result[:types_added].sort_by { |_k, v| -v }.each do |type, count|
        puts "  - #{type}: #{count} locations"
      end
    end

    if result[:errors].any?
      puts ""
      puts "Errors:"
      result[:errors].first(10).each do |error|
        puts "  - Location #{error[:location_id]}: #{error[:error]}"
      end
      puts "  ... and #{result[:errors].count - 10} more" if result[:errors].count > 10
    end

    puts ""
    puts "✅ Population complete!"
  end

  desc "Test classifier on a few locations (dry run)"
  task test_classifier: :environment do
    puts "🧪 Testing ExperienceTypeClassifier..."
    puts ""

    classifier = Ai::ExperienceTypeClassifier.new

    # Get 5 random locations without types
    locations = Location.left_joins(:location_experience_types)
      .where(location_experience_types: { id: nil })
      .distinct
      .limit(5)

    if locations.empty?
      puts "✓ All locations have experience types!"
      exit
    end

    puts "Testing on #{locations.count} locations:"
    puts ""

    locations.each do |location|
      result = classifier.classify(location, dry_run: true)

      puts "Location: #{location.name} (#{location.city})"
      puts "  Category: #{location.category_name || location.location_type}"

      if result[:success]
        puts "  ✓ Classified as: #{result[:types].join(', ')}"
      else
        puts "  ❌ Failed: #{result[:error]}"
      end
      puts ""
    end

    puts "✅ Test complete!"
  end
end
