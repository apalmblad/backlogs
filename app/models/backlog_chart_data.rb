class BacklogChartData < ActiveRecord::Base
  unloadable
  set_table_name 'backlog_chart_data'
  belongs_to :backlog

  def self.generate(backlog)
    # do not generate if end_date or start_date are not defined
    # or if the start date is still in the future
    # or if the backlog is already closed
    return nil if backlog.end_date.nil? || backlog.start_date.nil? ||
                  backlog.start_date > Date.today ||
                  backlog.is_closed?
    data_today = BacklogChartData.find :first, :conditions => ["backlog_id=? AND created_at=?", backlog.id, Date.today.to_formatted_s(:db)]

    scope = Item.sum('points', :conditions => ["items.backlog_id=? AND items.parent_id=0", backlog.id])
    total_hours = Item.sum('estimated_hours', :include => { :issue =>:status },
        :conditions => ["items.backlog_id=? AND items.parent_id=0 AND issue_statuses.is_closed=0", backlog.id])
    time_spent = Item.sum( 'time_entries.hours', :include => { :issue => :time_entries },
          :conditions => ["items.backlog_id=? AND items.parent_id=0", backlog.id] )
    done  = Item.sum('points', :include => {:issue => :status}, :conditions => ["items.parent_id=0 AND items.backlog_id=? AND issue_statuses.is_closed=?", backlog.id, true])
    wip   = 0
    if data_today.nil?
      data_today = new( :backlog_id => backlog.id, :created_at => Date.today.to_formatted_s(:db) )
    end
    data_today.attributes=( { :scope => scope, :done => done, :wip => wip, :total_hours =>total_hours, :time_spent => time_spent } )
    data_today.save!
    data_today
  end

  def self.fetch(options = {})
    backlog = Backlog.find(options[:backlog_id])
    if generate(backlog).nil?
        return nil
    end
    end_date = backlog.end_date
    data = find_all_by_backlog_id backlog.id, :conditions => ["created_at>=? AND created_at<=?", backlog.start_date.to_formatted_s(:db), end_date.to_formatted_s(:db)], :order => "created_at ASC"

    return nil if data.nil? || data.length==0

    data_points = (end_date - data.first.created_at.to_date).to_i + 1
    r_val = {:scope => [], :time_spent =>[], :total_hours => [], :done => [], :days => []}

    data.each do |d|
      r_val.keys.each do |k|
        if k == :days
          r_val[k]  << d.created_at
        else
          r_val[k] << d.send( k ) 
        end
      end
    end

    (1..(data_points-r_val[:days].length)).to_a.each do |i|
      r_val[:days] << r_val[:days].last + 1.day
    end
    [:scope, :time_spent,:total_hours].each do |k|
      r_val[k] = r_val[k].fill( r_val[k].last, r_val[k].length, data_points - r_val[k].length)
    end

    best = [r_val[:done].last]
    worst = [r_val[:done].last]
    speed = (best.last - r_val[:done].first).to_f / r_val[:done].length
    days_with_work = r_val[:done].length
    if days_with_work  > 1
      scope_last = r_val[:scope].last
      while best.last <  scope_last && best.last > 0 && (best.length +  days_with_work <= r_val[:scope].length)
        best << (best.last + speed*1.5).round(2)
      end
      best[best.length-1] = best.last > scope_last ? r_val[:scope].last : best.last

      while worst.last < scope_last && worst.last > 0 && (worst.length+ days_with_work <= r_val[:scope].length)
        worst << (worst.last + speed*0.5).round(2)
      end
      worst[worst.length-1] = worst.last > scope_last ? scope_last : worst.last
    end

    r_val[:best] = best
    r_val[:worst] = worst
    
    r_val.keys.each do |key|
      r_val["#{key}_x".to_sym] = (0...r_val[key].length).to_a
    end
    return r_val
  end
end
