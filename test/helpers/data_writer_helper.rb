require "logger"
require "thread"

require "db_helper"
require "ghostferry_helper"
require "mysql2"

module DataWriterHelper
  def start_datawriter_with_ghostferry(dw, gf, &on_write)
    gf.on_status(GhostferryHelper::Ghostferry::Status::READY) do
      dw.start(&on_write)
    end
  end

  def stop_datawriter_during_cutover(dw, gf)
    gf.on_status(GhostferryHelper::Ghostferry::Status::ROW_COPY_COMPLETED) do
      # At the start of the cutover phase, we have to set the database to
      # read-only. This is done by stopping the datawriter.
      dw.stop_and_join
    end
  end

  class DataWriter
    # A threaded data writer that just hammers the database with write
    # queries as much as possible.
    #
    # This is used essentially for random testing.
    def initialize(db_config,
                   tables: [DbHelper::DEFAULT_FULL_TABLE_NAME],
                   insert_probability: 0.33,
                   update_probability: 0.33,
                   delete_probability: 0.34,
                   number_of_writers: 1,
                   logger: nil
                  )
      @db_config = db_config
      @tables = tables

      @number_of_writers = number_of_writers
      @insert_probability = [0, insert_probability]
      @update_probability = [@insert_probability[1], @insert_probability[1] + update_probability]
      @delete_probability = [@update_probability[1], @update_probability[1] + delete_probability]

      @threads = []
      @started = false
      @stop_requested = false

      @start_cmd = Queue.new
      start_synchronized_datawriter_threads

      @logger = logger
      if @logger.nil?
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG
      end
    end

    def start(&on_write)
      raise "Cannot start DataWriter multiple times. Use a new instance instead " if @started

      @number_of_writers.times { @start_cmd << on_write }
      @started = true
    end

    def stop_and_join
      @stop_requested = true
      join
    end

    def join
      @threads.each do |t|
        t.join
      end
    end

    def write_data(connection, &on_write)
      r = rand

      if r >= @insert_probability[0] && r < @insert_probability[1]
        id = insert_data(connection)
        op = "INSERT"
      elsif r >= @update_probability[0] && r < @update_probability[1]
        id = update_data(connection)
        op = "UPDATE"
      elsif r >= @delete_probability[0] && r < @delete_probability[1]
        id = delete_data(connection)
        op = "DELETE"
      end

      on_write.call(op, id) unless on_write.nil?
    end

    def insert_data(connection)
      table = @tables.sample
      insert_statement = connection.prepare("INSERT INTO #{table} (id, data) VALUES (?, ?)")
      insert_statement.execute(nil, DbHelper.rand_data)
      connection.last_id
    ensure
      insert_statement&.close
    end

    def update_data(connection)
      table = @tables.sample
      id = random_real_id(connection, table)
      update_statement = connection.prepare("UPDATE #{table} SET data = ? WHERE id >= ? LIMIT 1")
      update_statement.execute(DbHelper.rand_data, id)
      id
    ensure
      update_statement&.close
    end

    def delete_data(connection)
      table = @tables.sample
      id = random_real_id(connection, table)
      delete_statement = connection.prepare("DELETE FROM #{table} WHERE id >= ? LIMIT 1")
      delete_statement.execute(id)
      id
    ensure
      delete_statement&.close
    end

    def random_real_id(connection, table)
      # This query is slow for large datasets.
      # For testing purposes, this should be okay.
      result = connection.query("SELECT id FROM #{table} ORDER BY RAND() LIMIT 1")
      raise "No rows in the database?" if result.first.nil?
      result.first["id"]
    end

    private

    def start_synchronized_datawriter_threads
      @number_of_writers.times do |i|
        @threads << Thread.new do
          connection = Mysql2::Client.new(@db_config)
          @logger.info("data writer thread in wait mode #{i}")
          on_write = @start_cmd.pop
          @logger.info("starting data writer thread #{i}")

          n = 0
          until @stop_requested do
            write_data(connection, &on_write)
            n += 1
            # Kind of makes the following race condition a bit better...
            # https://github.com/Shopify/ghostferry/issues/280
            sleep(0.03)
          end

          @logger.info("stopped data writer thread #{i} with a total of #{n} data writes")
        ensure
          connection&.close
        end
      end
    end
  end
end
