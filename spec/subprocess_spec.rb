require 'tempfile'
require 'ostruct'
require File.expand_path('../spec_helper', __FILE__)
require File.expand_path('../../lib/rest-assured/utils/subprocess', __FILE__)

module RestAssured::Utils
  describe Subprocess do

    it 'forks passed block' do
      ppid_file = Tempfile.new('ppidfile')
      Process.stub(:kill)

      Subprocess.new do
        ppid_file.write(Process.ppid)
        ppid_file.rewind
      end
      sleep 0.5

      ppid_file.read.should == Process.pid.to_s
    end

    it 'ensures no zombies' do
      Kernel.stub(:fork).and_return(pid = 1)
      Process.should_receive(:detach).with(pid)

      Subprocess.new {1}
    end

    it 'knows when it is running' do
      res_file = Tempfile.new('res')
      fork do
        at_exit { exit! }
        child = Subprocess.new { sleep 0.5 }
        res_file.write(child.alive?)
        res_file.rewind
      end
      Process.wait
      res_file.read.should == 'true'
    end

    it 'shuts down child when stopped' do
      child = Subprocess.new { sleep 2 }
      child.stop
      sleep 0.5
      child.alive?.should == false
    end

    describe 'commits seppuku' do
      it 'if child raises exception' do
        res_file = Tempfile.new('res')
        fork do
          at_exit { exit! }
          Subprocess.new { raise; sleep 1 }
          sleep 0.5
          res_file.write('should not exist because this process should be killed by now')
          res_file.rewind
        end
        Process.wait
        res_file.read.should == ''
      end

      it 'if child just quits' do
        res_file = Tempfile.new('res')
        fork do
          at_exit { exit! }
          Subprocess.new { 1 }
          sleep 0.5
          res_file.write('should not exist because this process should be killed by now')
          res_file.rewind
        end
        Process.wait
        res_file.read.should == ''
      end
    end

    context 'shuts down child process' do
      let(:child_pid) do
        Tempfile.new('child_pid')
      end

      let(:child_alive?) do
        begin
          Process.kill(0, child_pid.read.to_i)
          true
        rescue Errno::ESRCH
          false
        end
      end

      it 'when exits normally' do
        child_pid # Magic touch. Literally. Else Tempfile gets created in fork and that messes things up

        fork do
          at_exit { exit! }
          child = Subprocess.new { sleep 2 }
          child_pid.write(child.pid)
          child_pid.rewind
        end

        sleep 0.5
        child_alive?.should == false
      end

      it 'when killed violently' do
        child_pid

        fork do
          at_exit { exit! }
          child = Subprocess.new { sleep 2 }
          child_pid.write(child.pid)
          child_pid.rewind

          Process.kill('TERM', Process.pid)
        end
        
        sleep 0.5
        child_alive?.should == false
      end
    end
  end
end
