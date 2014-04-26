# rubywarrior AI
class Player
  DIRS = [:forward, :right, :backward, :left]
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
      unless tasks.empty? || warrior.health == MAX_HP
        tasks.push(Task.new(warrior.health))
      end
      tasks.sort!
      if tasks.empty?
        warrior.walk!(@prev_step = warrior.direction_of_stairs)
      else
        action(tasks.first.tag, tasks.first.space)
      end
    end
  end

  def action(mode, target_space)
    dir = @warrior.direction_of(target_space) unless target_space.nil?
    case mode
    when :ticking
      if @warrior.feel(dir).ticking?
        @prev_step = nil
        @warrior.rescue!(dir)
      else
        path(dir)
      end
    when :hp
      adj_enemies = scout.select { |space| space.enemy? }
      # @prev_step = nil
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
        @prev_step = nil
        @warrior.rescue!(dir)
      else
        path(dir)
      end
    end
  end

  def path(desired_dir)
    progress = scout(desired_dir).select { |space| space.empty? }
    progress.reject! { |space| space.stairs? }
    progress.reject! { |space| regress?(@warrior.direction_of(space)) }
    if progress.empty?
      overwhelming_odds(desired_dir)
    else
      @warrior.walk!(@prev_step = @warrior.direction_of(progress.first))
    end
  end

  def scout(target = :forward)
    i = DIRS.index(target)
    focused_scout = []
    (0..3).each do |offset|
      focused_scout.push(@warrior.feel(DIRS[(i + offset) % DIRS.length]))
    end
    focused_scout
  end

  def overwhelming_odds(target)
    adj_enemies = scout(target).select { |space| space.enemy? }
    if adj_enemies.length == 1
      # @prev_step = nil
      @warrior.attack!(@warrior.direction_of(adj_enemies.first))
    else
      @warrior.bind!(@warrior.direction_of(adj_enemies.last))
    end
  end

  def regress?(dir)
    if @prev_step.nil?
      false
    else
      dir == DIRS[(DIRS.index(@prev_step) + 2) % DIRS.length]
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
