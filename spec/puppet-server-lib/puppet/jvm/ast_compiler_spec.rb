require 'spec_helper'

require 'puppet_pal'

require 'puppet/server/ast_compiler'

def generate_ast(code)
  Puppet::Pal.in_tmp_environment("ast") do |pal|
    pal.with_catalog_compiler do |compiler|
      ast = compiler.parse_string(code)
      Puppet::Pops::Serialization::ToDataConverter.convert(ast,
                                                           rich_data: true,
                                                           symbol_to_string: true)
    end
  end
end

def request(code)
  {"certname" => "localhost",
   "facts" => {"values" => {"my_fact" => "fact_value"}},
   "trusted_facts" => {"values" => {"my_trusted" => "trusted_value"}},
   "options" => {"capture_logs" => false},
   "environment" => "production",
   "code_ast" => generate_ast(code).to_json,
   "variables" => {"values" => {"foo" => "bar"}}}
end

def find_notify(catalog)
  catalog['resources'].find do |item|
    item['type'] == 'Notify'
  end
end

describe Puppet::Server::ASTCompiler do
  context 'when compiling AST' do
    it 'handles basic resources' do
      response = Puppet::Server::ASTCompiler.compile(request("notify { 'my_notify': }"))
      notify = find_notify(response[:catalog])
      expect(notify).not_to be_nil
      expect(notify['title']).to eq("my_notify")
    end

    it 'correctly interpolates supplied variables' do
      response = Puppet::Server::ASTCompiler.compile(request('notify { "$foo": }'))
      notify = find_notify(response[:catalog])
      expect(notify).not_to be_nil
      expect(notify['title']).to eq("bar")
    end

    it 'correctly interpolates supplied facts' do
      response = Puppet::Server::ASTCompiler.compile(request('notify { "$my_fact": }'))
      notify = find_notify(response[:catalog])
      expect(notify).not_to be_nil
      expect(notify['title']).to eq("fact_value")
    end

    it 'correctly interpolates supplied trusted facts' do
      response = Puppet::Server::ASTCompiler.compile(request('notify { "${trusted[\'my_trusted\']}": }'))
      notify = find_notify(response[:catalog])
      expect(notify).not_to be_nil
      expect(notify['title']).to eq("trusted_value")
    end
  end
end
