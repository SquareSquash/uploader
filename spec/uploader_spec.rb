# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe Squash::Uploader do
  describe "#transmit" do
    before :each do
      @uploader = Squash::Uploader.new('https://test.host')
    end

    it "should call #http_post with the data" do
      expect(@uploader).to receive(:http_post).once.with("https://test.host/my/path",
                                                            {'Content-Type' => 'application/json'},
                                                            [{'my_data' => 'data'}.to_json]
      )
      @uploader.transmit('/my/path', 'my_data' => 'data')
    end
  end

  describe "#http_post" do
    before :each do
      @http = double('Net::HTTP')
      allow(@http).to receive(:open_timeout=)
      allow(@http).to receive(:read_timeout=)
      allow(@http).to receive(:use_ssl=)
      allow(@http).to receive(:verify_mode=)
      @session = double('Net::HTTP session')
      allow(@session).to receive(:request).and_return(Net::HTTPSuccess.new('1.1', '200', 'OK'))
      allow(@http).to receive(:start).and_yield(@session)

      allow(Net::HTTP).to receive(:new).and_return(@http)
    end

    it "should make the HTTP POST request" do
      expect(Net::HTTP).to receive(:new).once.with('test.host', 80).and_return(@http)

      expect(@http).to receive(:open_timeout=).once.with(15)
      expect(@http).to receive(:read_timeout=).once.with(15)
      expect(@http).to receive(:use_ssl=).once.with(false)

      session = double('Net::HTTP session')
      expect(@http).to receive(:start).once.and_yield(session)
      expect(session).to receive(:request).twice.with { |post|
        expect(post.method).to eql('POST')
        expect(post.body).to match(/BODY[12]/)
        expect(post.path).to eql('/foo')
        expect(post['X-Foo']).to eql('Bar')
      }.and_return(Net::HTTPSuccess.new('1.1', '200', 'OK'))

      Squash::Uploader.new('').send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(BODY1 BODY2)
    end

    it "should set use_ssl for https requests" do
      expect(@http).to receive(:use_ssl=).once.with(true)
      Squash::Uploader.new('').send :http_post, 'https://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo)
    end

    it "should set verify_mode to NONE if skipping verification" do
      expect(@http).to receive(:verify_mode=).once.with(OpenSSL::SSL::VERIFY_NONE)
      Squash::Uploader.new('', :skip_verification => true).send :http_post, 'https://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo)
    end

    it "should raise an error for invalid responses" do
      allow(@session).to receive(:request).and_return(Net::HTTPBadRequest.new('1.1', '400', 'Bad Request'))
      expect { Squash::Uploader.new('').send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo) }.to raise_error(/400/)

      allow(@session).to receive(:request).and_return(Net::HTTPBadRequest.new('1.1', '201', 'Created'))
      expect { Squash::Uploader.new('', :success => [Net::HTTPOK]).send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo) }.to raise_error(/201/)
    end
  end
end
