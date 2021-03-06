require 'spec_helper'

describe Policial::StyleChecker do
  describe '#violations' do
    it 'returns a collection of computed violations' do
      stylish_file = stub_commit_file('good.rb', 'def good; end')
      violated_file = stub_commit_file('bad.rb', 'def bad( a ); a; end  ')
      bad_coffee = stub_commit_file('bad.coffee', 'foo: =>')
      pull_request =
        stub_pull_request(files: [stylish_file, violated_file, bad_coffee])
      expected_violations = [
        'Avoid single-line method definitions.',
        'Space inside parentheses detected.',
        'Space inside parentheses detected.',
        'Trailing whitespace detected.',
        'Unnecessary fat arrow'
      ]

      violation_messages =
        described_class.new(pull_request).violations.map(&:message)

      expect(violation_messages).to eq expected_violations
    end

    it 'forwards options to the style guides, as well as a config loader' do
      file = stub_commit_file('ruby.rb', 'puts 123')
      head_commit = double('Commit', file_content: '')
      pull_request = stub_pull_request(head_commit: head_commit, files: [file])
      config_loader = Policial::ConfigLoader.new(head_commit)

      expect(Policial::ConfigLoader).to receive(:new).with(
        head_commit).and_return(config_loader)

      expect(Policial::StyleGuides::Ruby).to receive(:new).with(
        config_loader, my: :options).and_call_original
      expect(Policial::StyleGuides::CoffeeScript).to receive(:new).with(
        config_loader, a_few: :more_options).and_call_original

      described_class.new(
        pull_request,
        ruby: { my: :options },
        coffeescript: { a_few: :more_options }
      ).violations
    end

    it 'skips style guides on files that they are not able to investigate' do
      allow_any_instance_of(Policial::StyleGuides::Ruby)
        .to receive(:investigate?).with('a.rb').and_return(false)
      allow_any_instance_of(Policial::StyleGuides::Ruby)
        .to receive(:investigate?).with('b.rb').and_return(true)

      file_a = stub_commit_file('a.rb', '"double quotes"')
      file_b = stub_commit_file('b.rb', ':trailing_withespace ')
      pull_request = stub_pull_request(files: [file_a, file_b])
      expected_violations = ['Trailing whitespace detected.']

      violation_messages =
        described_class.new(pull_request).violations.map(&:message)

      expect(violation_messages).to eq expected_violations
    end

    private

    def stub_pull_request(options = {})
      head_commit = double('Commit', file_content: '')
      defaults = {
        file_content: '',
        head_commit: head_commit,
        files: []
      }

      double('PullRequest', defaults.merge(options))
    end

    def stub_commit_file(filename, contents, line = nil)
      line ||= Policial::Line.new(1, 'foo', 2)
      formatted_contents = "#{contents}\n"
      double(
        filename.split('.').first,
        filename: filename,
        content: formatted_contents,
        removed?: false,
        line_at: line
      )
    end
  end
end
