# rubywarrior AI
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]
  MAX_HP = 20
  PRIORITIES = { ticking: 1, hp: 2, enemy: 3, captive: 4 }
  @heal_cycle = false

  def play_turn(warrior)
    @warrior = warrior

    if @heal_cycle
      # crude healing cycle control
      @heal_cycle = false if warrior.health >= MAX_HP * 0.85
      warrior.rest!
    else
      tasks = warrior.listen.map { |space| Task.new(space) }
      tasks.push(Task.new(warrior.health)) unless tasks.empty? || warrior.health == MAX_HP
      tasks.sort!
      if tasks.empty?
        @prev_dir = warrior.direction_of_stairs
        warrior.walk!(@prev_dir)
      else
        action(tasks.first.tag, tasks.first.space)
      end
    end
  end

  def action(mode, space)
    dir = @warrior.direction_of(space) unless space.nil?
    case mode
    when :ticking
      if @warrior.feel(dir).ticking?
        @prev_dir = nil
        @warrior.rescue!(dir)
      else
        path(dir)
      end
    when :hp
      adj_enemies = scout.select! { |s| s.enemy? }
      @prev_dir = nil
      if adj_enemies.empty?
        @heal_cycle = true
        @warrior.rest!
      else
        @warrior.bind!(@warrior.direction_of(adj_enemies.first))
      end
    when :enemy
      if @warrior.feel(dir).enemy?
        overwhelming_odds(dir)
      else
        path(dir)
      end
    when :captive
      if @warrior.feel(dir).captive?
        @prev_dir = nil
        @warrior.rescue!(dir)
      else
        path(dir)
      end
    end
  end

  def path(desired_dir)
    progress_spaces = []
    i = DIRECTIONS.index(desired_dir)

    DIRECTIONS.map { |dir| progress_spaces.push(@warrior.feel(dir)) if dir == desired_dir || (dir == DIRECTIONS[(i + 1) % DIRECTIONS.length] && !regress?(dir)) || (dir == DIRECTIONS[(i + 3) % DIRECTIONS.length] && !regress?(dir)) }

    progress_spaces.select! { |s| s.empty? && !s.stairs? }
    if progress_spaces.empty?
      overwhelming_odds(desired_dir)
    else
      @warrior.walk!(@prev_dir = @warrior.direction_of(progress_spaces.first))
    end
  end

  def scout(*target)
    if target.empty?
      DIRECTIONS.map { |dir| @warrior.feel(dir) }
    else
      i = DIRECTIONS.index(target.first)
      focused_scout = []
      (0..3).each { |offset| focused_scout.push(@warrior.feel(DIRECTIONS[(i + offset) % DIRECTIONS.length])) }
      focused_scout
    end
  end

  def overwhelming_odds(target)
    adj_enemies = scout(target).select! { |s| s.enemy? }
    @prev_dir = nil
    if adj_enemies.length == 1
      @warrior.attack!(@warrior.direction_of(adj_enemies.first))
    else
      @warrior.bind!(@warrior.direction_of(adj_enemies.last))
    end
  end

  def regress?(dir)
    if @prev_dir.nil?
      false
    else
      dir == DIRECTIONS[(DIRECTIONS.index(@prev_dir) + 2) % DIRECTIONS.length]
    end
  end

  # each Task has a tag, a priority and possibly an associated space object
  class Task
    attr_reader :priority, :tag, :space

    def initialize(cause)
      if cause.respond_to?(:empty?) # test for space object
        @priority = score(@space = cause)
      else
        # custom low hp priority modifier
        @priority =
          PRIORITIES.size - PRIORITIES[@tag = :hp] + (MAX_HP * 0.25 - cause)
      end
    end

    def score(space)
      if space.ticking?
        @tag = :ticking
      elsif space.enemy?
        @tag = :enemy
      elsif space.captive?
        @tag = :captive
      end
      PRIORITIES.size - PRIORITIES[@tag]
    end

    # used to sort! tasks in descending priority
    def <=>(other)
      if priority < other.priority
        1
      elsif priority > other.priority
        -1
      else # priority == other.priority
        0
      end
    end
  end
end
