# an older version of 20111007115901_group_categories_data_migration.rb was
# broken and did not update assignments correctly. the current version is
# fixed, but if you ran the broken one, this will clean it up. if you ran the
# fixed one, this migration is a no-op.
class GroupCategoriesCleanupMigration < ActiveRecord::Migration
  def self.uncached_group_category_id_for(context, name)
    if !context.is_a?(Account) && name == "Student Groups"
      GroupCategory.student_organized_for(context).id
    elsif name == "Imported Groups"
      GroupCategory.imported_for(context).id
    else
      context.group_categories.find_or_create_by_name(name).id
    end
  end

  def self.group_category_id_for(record)
    context = record.context
    name = record.group_category_name
    @cache ||= {}
    @cache[context] ||= {}
    @cache[context][name] ||= uncached_group_category_id_for(context, name)
  end

  def self.update_records_for_record(record)
    return unless record.context.present? and record.group_category_name.present?
    category_column = (record.class == Group ? 'category' : 'group_category')
    records = record.class.scoped(:conditions => ["context_id=? AND context_type=? AND #{category_column}=? AND group_category_id IS NULL",
      record.context_id,
      record.context_type,
      record.group_category_name])
    records.update_all({:group_category_id => group_category_id_for(record)})
  end

  def self.up
    Assignment.find(:all, :select => "DISTINCT context_id, context_type, group_category",
      :conditions => ['context_id IS NOT NULL AND group_category IS NOT NULL AND group_category_id IS NULL']).each do |record|
      update_records_for_record(record)
    end
  end

  def self.down
  end
end
