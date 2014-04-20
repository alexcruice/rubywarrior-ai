# rubywarrior AI
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]
  MAX_HP = 20
  PRIORITIES = { ticking: 1, hp: 2, enemy: 3, captive: 4 }
  @heal = false

  def play_turn(warrior)
    @warrior = warrior

    if @heal
      # crude healing cycle control
      @heal = false if warrior.health >= MAX_HP * 0.9
      warrior.rest!
    else
      tasks = warrior.listen.map { |space| Task.new(warrior.health, space) }
      tasks.push(Task.new(warrior.health, nil)) if warrior.health < MAX_HP
      tasks.sort!
      tasks.empty? ? warrior.walk!(warrior.direction_of_stairs) : action(tasks.first.tag, tasks.first.space)
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
      adj_enemies = DIRECTIONS.map { |dir| @warrior.feel(dir) }
      adj_enemies.select! { |s| s.enemy? }
      @prev_dir = nil
      if adj_enemies.empty?
        @heal = true
      else
        @warrior.bind!(@warrior.direction_of(adj_enemies.first))
      end
    when :enemy
      if @warrior.feel(dir).enemy?
        @prev_dir = nil
        @warrior.attack!(dir)
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
      adj_enemies = DIRECTIONS.map { |dir| @warrior.feel(dir) }
      adj_enemies.select! { |s| s.enemy? }
      @prev_dir = nil
      if adj_enemies.length == 1
        @warrior.attack!(@warrior.direction_of(adj_enemies.first))
      else
        @warrior.bind!(@warrior.direction_of(adj_enemies.last))
      end
    else
      @prev_dir = @warrior.direction_of(progress_spaces.first)
      @warrior.walk!(@prev_dir)
    end
  end

  def regress?(dir)
    @prev_dir.nil? ? false : dir == DIRECTIONS[(DIRECTIONS.index(@prev_dir) + 2) % DIRECTIONS.length]
  end

  # each Task has a tag, priority and maybe a space object attached
  class Task
    attr_reader :priority, :tag, :space

    def initialize(hp, space)
      if space.nil?
        # low hp priority modifier
        @priority = PRIORITIES.size - PRIORITIES[@tag = :hp]# + (MAX_HP / 2 - hp)
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
      end
      PRIORITIES.size - PRIORITIES[@tag]
    end

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
