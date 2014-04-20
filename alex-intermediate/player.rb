# rubywarrior AI
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]
  MAX_HP = 20
  PRIORITIES = { ticking: 1, hp: 2, enemy: 3, captive: 4, stairs: 5 }

  def play_turn(warrior)
    @warrior = warrior
    @curr_hp = warrior.health
    @prev_hp = @curr_hp if @prev_hp.nil?

    tasks = warrior.listen.map { |space| Task.new(space) }
    tasks.push(Task.new) # hp task (space-less)
    tasks.sort!
    action(tasks.first.tag, warrior.direction_of(tasks.first.space))

    @prev_hp = @curr_hp
  end

  def action(mode, *dir)
    case mode
    when :ticking
      if @warrior.feel(dir).ticking?
        @prev_dir = nil
        @warrior.rescue!(dir)
      else
        path(dir, :ticking)
      end
    when :hp
      # TODO
    when :enemy
      if @warrior.feel(dir).enemy?
        @prev_dir = nil
        @warrior.attack!(dir)
      else
        path(dir, :ticking)
      end
    when :captive
      if @warrior.feel(dir).captive?
        @prev_dir = nil
        @warrior.rescue!(dir)
      else
        path(dir, :ticking)
      end
    when :stairs
      @warrior.walk!(@warrior.direction_of_stairs)
    end
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
    end
  end

  def regress?(dir)
    @prev_dir.nil? ? false : dir == DIRECTIONS[(DIRECTIONS.index(@prev_dir) + 2) % DIRECTIONS.length]
  end
end

# each Task has a tag, priority and maybe a space object attached
class Task
  include Comparable
  attr_reader :priority, :tag, :space

  def initialize(*space)
    if space.nil?
      # low hp priority modifier
      @priority = PRIORITIES.size - PRIORITIES[@tag = :hp] + (MAX_HP / 2 - @curr_hp)
    else
      @priority = score(@space = space)
    end
  end

  def score(space)
    if space.ticking?
      @tag = :ticking
    elsif space.enemy?
      @tag = :enemy
    elsif space.captive?
      @tag = :captive
    elsif space.stairs?
      @tag = :stairs
    end
    PRIORITIES.size - PRIORITIES[@tag]
  end

  def <=>(other)
    -1 if priority < other.priority
    0 if priority == other.priority
    1 if priority > other.priority
  end
end
