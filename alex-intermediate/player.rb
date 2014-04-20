# rubywarrior AI
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]
  MAX_HP = 20

  def play_turn(warrior)
    @warrior = warrior
    @curr_hp = warrior.health
    @prev_hp = @curr_hp if @prev_hp.nil?

    @soi = warrior.listen.select { |s| s.ticking? }

    action(warrior.direction_of(@soi.first), :ticking)

    @prev_hp = @curr_hp
  end

  def path(desired_dir, mode)
    progress_spaces = []
    i = DIRECTIONS.index(desired_dir)

    DIRECTIONS.map { |dir| progress_spaces.push(@warrior.feel(dir)) if dir == desired_dir || (dir == DIRECTIONS[(i + 1) % DIRECTIONS.length] && !regress?(dir)) || (dir == DIRECTIONS[(i + 3) % DIRECTIONS.length] && !regress?(dir)) }

    case mode
    when :ticking
      progress_spaces.select! { |s| s.empty? && !s.stairs? }
      @prev_dir = @warrior.direction_of(progress_spaces.first)
      @warrior.walk!(@prev_dir)
    else
    end
  end

  def action(dir, mode)
    case mode
    when :ticking
      @warrior.feel(dir).ticking? ? @warrior.rescue!(dir) : path(dir, :ticking)
    else
    end
  end

  def regress?(dir)
    @prev_dir.nil? ? false : dir == DIRECTIONS[(DIRECTIONS.index(@prev_dir) + 2) % DIRECTIONS.length]
  end
end
