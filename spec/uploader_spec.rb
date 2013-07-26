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
      @uploader.should_receive(:http_post).once.with("https://test.host/my/path",
                                                            {'Content-Type' => 'application/json'},
                                                            [{'my_data' => 'data'}.to_json]
      )
      @uploader.transmit('/my/path', 'my_data' => 'data')
    end
  end

  describe "#http_post" do
    before :each do
      @http = mock('Net::HTTP')
      @http.stub!(:open_timeout=)
      @http.stub!(:read_timeout=)
      @http.stub!(:use_ssl=)
      @http.stub!(:verify_mode=)
      @session = mock('Net::HTTP session')
      @session.stub!(:request).and_return(Net::HTTPSuccess.new('1.1', '200', 'OK'))
      @http.stub!(:start).and_yield(@session)

      Net::HTTP.stub!(:new).and_return(@http)
    end

    it "should make the HTTP POST request" do
      Net::HTTP.should_receive(:new).once.with('test.host', 80).and_return(@http)

      @http.should_receive(:open_timeout=).once.with(15)
      @http.should_receive(:read_timeout=).once.with(15)
      @http.should_receive(:use_ssl=).once.with(false)

      session = mock('Net::HTTP session')
      @http.should_receive(:start).once.and_yield(session)
      session.should_receive(:request).twice.with do |post|
        post.method.should eql('POST')
        post.body.should =~ /BODY[12]/
        post.path.should eql('/foo')
        post['X-Foo'].should eql('Bar')
      end.and_return(Net::HTTPSuccess.new('1.1', '200', 'OK'))

      Squash::Uploader.new('').send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(BODY1 BODY2)
    end

    it "should set use_ssl for https requests" do
      @http.should_receive(:use_ssl=).once.with(true)
      Squash::Uploader.new('').send :http_post, 'https://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo)
    end

    it "should set verify_mode to NONE if skipping verification" do
      @http.should_receive(:verify_mode=).once.with(OpenSSL::SSL::VERIFY_NONE)
      Squash::Uploader.new('', :skip_verification => true).send :http_post, 'https://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo)
    end

    it "should raise an error for invalid responses" do
      @session.stub!(:request).and_return(Net::HTTPBadRequest.new('1.1', '400', 'Bad Request'))
      lambda { Squash::Uploader.new('').send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo) }.should raise_error(/400/)

      @session.stub!(:request).and_return(Net::HTTPBadRequest.new('1.1', '201', 'Created'))
      lambda { Squash::Uploader.new('', :success => [Net::HTTPOK]).send :http_post, 'http://test.host/foo', {'X-Foo' => 'Bar'}, %w(foo) }.should raise_error(/201/)
    end
  end
end
