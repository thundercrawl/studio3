require "java"
require "ruble/base_element"
require "ruble/bundle_manager"

module Ruble
  
  class Bundle < BaseElement
    @@defaults = {}
    
    def initialize(name, default_values={})
      if name.kind_of? String
        super(name)
        @@defaults[path.to_sym] = default_values
      else
        # hack to pass in java object...should test type
        @jobj = name
      end
    end
    
    def add_command(command)
      @jobj.add_command command.java_object
    end
    
    def add_menu(menu)
      @jobj.add_menu menu.java_object
    end
    
    def add_snippet(snippet)
      @jobj.add_snippet snippet.java_object
    end
    
    def apply_defaults(obj)
      if obj.nil? == false
        defaults.each do |k,v|
          property = "#{k.to_s}=".to_sym
          
          if obj.respond_to?(property)
            obj.send(property, v)
          end
        end
      end
    end
    
    def author
      @jobj.author
    end
    
    def author=(author)
      @jobj.author = author
    end
    
    def copyright
      @jobj.copyright
    end
    
    def copyright=(copyright)
      @jobj.copyright = copyright
    end
    
    def defaults
      @@defaults[path.to_sym] ||= {}
    end
    
    def defaults=(defaults)
      @@defaults[path.to_sym] = defaults
    end
    
    def description
      @jobj.description
    end
    
    def description=(description)
      @jobj.description = description
    end
    
    def menu(name, &block)
      Menu.define_menu(name, &block)
    end
    
    def name
      @jobj.display_name
    end
    
    def repository
      @jobj.repository
    end
    
    def repository=(repository)
      @jobj.repository = repository
    end
    
    def license
      @jobj.license
    end
    
    def license=(license)
      @jobj.license = license.join("\n")
    end
    
    def license_url
      @jobj.license_url
    end
    
    def license_url=(license_url)
      @jobj.license_url = license_url.join("\n")
    end
    
    # A proxy class to make syntax pretty...
    class FileTypesProxy
      def initialize(jobj)
        @jobj = jobj
      end
      
      def []=(scope, array)
        array.each do |file_type|
          @jobj.associateFileType(file_type.to_s)
          @jobj.associateScope(file_type.to_s, scope.to_s.gsub(/_/, '.'))
        end
      end
    end
    
    # Used to associate a top-level scope and the Aptana editors with an array of filetype patterns
    # i.e. bundle.file_types['scope.name'] = '*.xml', '*xsl', '*.xslt'
    def file_types
      FileTypesProxy.new(@jobj)
    end    
    
    # TODO These following two methods should be deprecated in place of new syntax: file_types['scope'] = ['patterns', ...]
    
    # This method does two things:
    # If the given file type is not associated with any editor, we associate it with our generic text editor
    # We also register a top-level scope to report back for any file whose name matches the file type pattern.
    # Understands * wildcard. Typical values for first arg: '*.yml', '*_spec.rb', 'Rakefile'
    # scope is a string or a symbol. Underscores are converted to spaces (so 'source.yaml' and :source_yaml are equivalent)
    def register_file_type(file_type, scope)
      associate_scope(file_type, scope)
      @jobj.associateFileType(file_type.to_s)
    end
    
    # Registers a top-level scope to report back for any file whose name matches the passed in pattern.
    # Understands * wildcard. Typical values for first arg: '*.yml', '*_spec.rb', 'Rakefile'
    # scope is a string or a symbol. Underscores are converted to spaces (so 'source.yaml' and :source_yaml are equivalent)
    def associate_scope(file_type, scope)
      @jobj.associateScope(file_type, scope.to_s.gsub(/_/, '.'))
    end
    
    # A proxy class to make syntax pretty...
    class FoldingProxy
      def initialize(jobj)
        @jobj = jobj
      end
      
      def []=(scope, array)
        raise "Need two regexp to define folding" if array.size != 2
        @jobj.setFoldingMarkers(scope.to_s.gsub(/_/, '.'), array.first, array.last)
      end
    end
    
    def folding
      # return an object that responds to hash methods
      FoldingProxy.new(@jobj)
    end
    
    # TODO Deprecate
    def set_folding_markers(scope, start_regexp, end_regexp)
      folding[scope] = start_regexp, end_regexp
    end
    
    # A proxy class to make syntax pretty...
    class IndentProxy
      def initialize(jobj)
        @jobj = jobj
      end
      
      def []=(scope, array)
        raise "Need two regexp to define indent" if array.size != 2
        @jobj.setIndentMarkers(scope.to_s.gsub(/_/, '.'), array.first, array.last)
      end
    end    
    
    def indent
      # return an object that responds to hash methods
      IndentProxy.new(@jobj)
    end
    
    def to_env
      { :TM_BUNDLE_SUPPORT => File.join(File.dirname(path), "lib") }
    end
    
    def to_s
      <<-EOS
      bundle(
        author: #{author}
      )
      EOS
    end
    
    class << self
      def define_bundle(name="", values={}, &block)
        log_info("loading bundle #{name}")
        
        # create new bundle and add to bundle manager so the block, if given
        # can lookup the bundle by path name
        bundle = Bundle.new(name, values)
        BundleManager.add_bundle(bundle)
        block.call(bundle) if block_given?
      end
    end
  
  private
    
    def create_java_object
      com.aptana.scripting.model.BundleElement.new($fullpath)
    end
  end
  
end

# define top-level convenience methods

def bundle(name="", &block)
  Ruble::Bundle.define_bundle(name, {}, &block)
end

def with_defaults(values, &block)
  bundle = Ruble::BundleManager.bundle_from_path(File.dirname($fullpath))
  
  if bundle.nil?
    bundle = Ruble::Bundle.define_bundle("", values, &block)
  else
    bundle.defaults = values
    block.call(bundle) if block_given?
    bundle.defaults = {}
  end
end
