App = require './script'

class Exporter extends App
  beginInitShaders: ->
    @output.push "\n\nstatic void init_shaders(CUBE_STATE_T *state)\n{"

  endInitShaders: ->
    @output.push "}"

  beginInitShapes: ->
    @output.push "\n\nstatic void init_shapes(CUBE_STATE_T *state)\n{"

  endInitShapes: ->
    @output.push "}"

  initCanvas: ->
  initGLContext: ->
    @GL =
      clearColor: ->

  createVertexAndFaceBuffers: (name, object, vertexData, facesData) ->
    @buffers.push {name, object, vertexData, facesData}
    block = (data, indent, size) ->
      indentString = new Array(indent + 1).join(" ")
      dataString = []
      for number, i in data
        if (i % size) == 0
          dataString.push "\n#{indentString}"
        dataString.push "#{number}, "
      dataString = dataString.join("").replace(/[\n, ]*$/, "")
      return dataString

    @output.push """

      //////////////////////
      // #{name} vertex data
      //////////////////////
        static const GLfloat #{name}VertexData[] = {#{block(vertexData, 4, 6)}
        };
        glGenBuffers(1, &state->#{name}VertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, state->#{name}VertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(#{name}VertexData), #{name}VertexData, GL_STATIC_DRAW);

      //////////////////////
      // #{name} faces data
      //////////////////////
        static unsigned int #{name}FacesData[] = {#{block(facesData, 4, 6)}
        };
        glGenBuffers(1, &state->#{name}FacesBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, state->#{name}FacesBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(#{name}FacesData), #{name}FacesData, GL_STATIC_DRAW);

      """

  initTexture: ->
    @output.push """
      static void init_texture(CUBE_STATE_T *state)
      {
        glGenTextures(1, &state->texture);
        //glPixelStorei(UNPACK_FLIP_Y_WEBGL, true);
        glBindTexture(TEXTURE_2D, state->texture);
        glTexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
        glTexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP_TO_EDGE);
        glTexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
        glTexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
        glBindTexture(TEXTURE_2D, null);
      }
      """
  initElements: ->
  createNamedShader: (name, attributes, uniforms) ->
    @shaders.push {name, attributes, uniforms}
    enableVertexArrays = (enable = true) ->
      tmp = []
      for varName in attributes
        tmp.push "  gl#{if enable then "Enable" else "Disable"}VertexAttribArray(state->#{name}_attr_#{varName});\n  check();"
      return tmp.join("\n")

    @shaderMethods.push """

      static void #{name}ShaderEnable(CUBE_STATE_T *state)
      {
        glUseProgram(state->#{name}Program);
        check();
      #{enableVertexArrays()}
      }

      static void #{name}ShaderDisable(CUBE_STATE_T *state)
      {
      #{enableVertexArrays(false)}
      }

      """
    output = @output
    output.push "  const GLchar *#{name}VertexShaderSource ="
    source = this["#{name}VertexShaderSource"]
    for line in source.split(/\n/)
      output.push "    \"#{line}\""
    output.push """

      //////////////////////
      // #{name} shader
      //////////////////////

        state->#{name}VertexShader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(state->#{name}VertexShader, 1, &#{name}VertexShaderSource, 0);
        glCompileShader(state->#{name}VertexShader);
        check();

        if (state->verbose) {
          showlog(state->#{name}VertexShader);
        }

        state->#{name}FragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(state->#{name}FragmentShader, 1, &#{name}FragmentShaderSource, 0);
        glCompileShader(state->#{name}FragmentShader);
        check();

        if (state->verbose) {
          showlog(state->#{name}FragmentShader);
        }

        state->#{name}Program = glCreateProgram();
        glAttachShader(state->#{name}Program, state->#{name}VertexShader);
        glAttachShader(state->#{name}Program, state->#{name}FragmentShader);
        glLinkProgram(state->#{name}Program);
        check();

        if (state->verbose) {
          showprogramlog(state->#{name}Program);
        }
      """

    for attribute in attributes
      output.push "  state->#{name}_attr_#{attribute} = glGetAttribLocation(state->#{name}Program, \"#{attribute}\");"
    for uniform in uniforms
      output.push "  state->#{name}_unif_#{uniform} = glGetUniformLocation(state->#{name}Program, \"#{uniform}\");"

  export: ->
    @output = []
    @shaderMethods = []
    @buffers = []
    @shaders = []

    @init()

    shaderDefinitions = ({name, attributes, uniforms}) ->
      tmp = []
      for attribute in attributes
        tmp.push "  GLuint #{name}_attr_#{attribute};"
      for uniform in uniforms
        tmp.push "  GLuint #{name}_unif_#{uniform};"
      tmp.push "  GLuint #{name}Program;"
      tmp.push "  GLuint #{name}VertexShader;"
      tmp.push "  GLuint #{name}FragmentShader;"
      return tmp.join("\n")

    @output.unshift """
      #include <stdio.h>
      #include <fcntl.h>
      #include <stdlib.h>
      #include <string.h>
      #include <math.h>
      #include <assert.h>
      #include <unistd.h>

      #include "bcm_host.h"

      #include "GLES2/gl2.h"
      #include "EGL/egl.h"
      #include "EGL/eglext.h"

      typedef struct
      {
        uint32_t screen_width;
        uint32_t screen_height;
      // OpenGL|ES objects
        EGLDisplay display;
        EGLSurface surface;
        EGLContext context;

        GLuint verbose;
        GLuint vshader;
        GLuint fshader;
        GLuint mshader;
        GLuint program;
        GLuint program2;
        GLuint outputTextureFramebuffer;
        GLuint outputTexture;

      #{(shaderDefinitions(shader) for shader in @shaders).join("\n\n")}

      #{(
      for {name} in @buffers
        "  GLuint #{name}VertexBuffer;\n" +
        "  GLuint #{name}FacesBuffer;\n"
      ).join("\n")}

      // julia attribs
        GLuint unif_color, attr_vertex, unif_scale, unif_offset, unif_tex, unif_centre;
      // mandelbrot attribs
        GLuint attr_vertex2, unif_scale2, unif_offset2, unif_centre2;
      } CUBE_STATE_T;

      static CUBE_STATE_T _state, *state=&_state;

      #define check() assert(glGetError() == 0)

      static void showlog(GLint shader)
      {
         // Prints the compile log for a shader
         char log[1024];
         glGetShaderInfoLog(shader,sizeof log,NULL,log);
         printf("%d:shader:\n%s\n", shader, log);
      }

      static void showprogramlog(GLint shader)
      {
         // Prints the information log for a program object
         char log[1024];
         glGetProgramInfoLog(shader,sizeof log,NULL,log);
         printf("%d:program:\n%s\n", shader, log);
      }
      """

    @output.push """
      static void init_ogl(CUBE_STATE_T *state)
      {
        int32_t success = 0;
        EGLBoolean result;
        EGLint num_config;

        static EGL_DISPMANX_WINDOW_T nativewindow;

        DISPMANX_ELEMENT_HANDLE_T dispman_element;
        DISPMANX_DISPLAY_HANDLE_T dispman_display;
        DISPMANX_UPDATE_HANDLE_T dispman_update;
        VC_RECT_T dst_rect;
        VC_RECT_T src_rect;

        static const EGLint attribute_list[] =
        {
           EGL_RED_SIZE, 8,
           EGL_GREEN_SIZE, 8,
           EGL_BLUE_SIZE, 8,
           EGL_ALPHA_SIZE, 8,
           EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
           EGL_NONE
        };

        static const EGLint context_attributes[] =
        {
           EGL_CONTEXT_CLIENT_VERSION, 2,
           EGL_NONE
        };
        EGLConfig config;

        // get an EGL display connection
        state->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        assert(state->display!=EGL_NO_DISPLAY);
        check();

        // initialize the EGL display connection
        result = eglInitialize(state->display, NULL, NULL);
        assert(EGL_FALSE != result);
        check();

        // get an appropriate EGL frame buffer configuration
        result = eglChooseConfig(state->display, attribute_list, &config, 1, &num_config);
        assert(EGL_FALSE != result);
        check();

        // get an appropriate EGL frame buffer configuration
        result = eglBindAPI(EGL_OPENGL_ES_API);
        assert(EGL_FALSE != result);
        check();

        // create an EGL rendering context
        state->context = eglCreateContext(state->display, config, EGL_NO_CONTEXT, context_attributes);
        assert(state->context!=EGL_NO_CONTEXT);
        check();

        // create an EGL window surface
        success = graphics_get_display_size(0 /* LCD */, &state->screen_width, &state->screen_height);
        assert( success >= 0 );

        dst_rect.x = 0;
        dst_rect.y = 0;
        dst_rect.width = state->screen_width;
        dst_rect.height = state->screen_height;

        src_rect.x = 0;
        src_rect.y = 0;
        src_rect.width = state->screen_width << 16;
        src_rect.height = state->screen_height << 16;

        dispman_display = vc_dispmanx_display_open( 0 /* LCD */);
        dispman_update = vc_dispmanx_update_start( 0 );

        dispman_element = vc_dispmanx_element_add ( dispman_update, dispman_display,
           0/*layer*/, &dst_rect, 0/*src*/,
           &src_rect, DISPMANX_PROTECTION_NONE, 0 /*alpha*/, 0/*clamp*/, 0/*transform*/);

        nativewindow.element = dispman_element;
        nativewindow.width = state->screen_width;
        nativewindow.height = state->screen_height;
        vc_dispmanx_update_submit_sync( dispman_update );

        check();

        state->surface = eglCreateWindowSurface( state->display, config, &nativewindow, NULL );
        assert(state->surface != EGL_NO_SURFACE);
        check();

        // connect the context to the surface
        result = eglMakeCurrent(state->display, state->surface, state->surface, state->context);
        assert(EGL_FALSE != result);
        check();

        // Set background color and clear buffers
        glClearColor(0.15f, 0.25f, 0.35f, 1.0f);
        glClear( GL_COLOR_BUFFER_BIT );

        check();
      }
      static void init_summink(CUBE_STATE_T *state)
      {
        glClearColor(0., 0., 0., 1.);

        // Prepare a texture image
        glGenTextures(1, &state->outputTexture);
        check();
        glBindTexture(GL_TEXTURE_2D,state->outputTexture);
        check();
        // glActiveTexture(0)
        glTexImage2D(GL_TEXTURE_2D,0,GL_RGB,state->screen_width,state->screen_height,0,GL_RGB,GL_UNSIGNED_SHORT_5_6_5,0);
        check();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        check();
        // Prepare a framebuffer for rendering
        glGenFramebuffers(1,&state->outputTextureFramebuffer);
        check();
        glBindFramebuffer(GL_FRAMEBUFFER,state->outputTextureFramebuffer);
        check();
        glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,state->outputTexture,0);
        check();
        glBindFramebuffer(GL_FRAMEBUFFER,0);
        check();
        // Prepare viewport
        glViewport ( 0, 0, state->screen_width, state->screen_height );
        check();
      }
      """
    @output = @output.concat(@shaderMethods)
    @output.push """

      static void draw_triangles(CUBE_STATE_T *state)
      {
        // Now render to the main frame buffer
        glBindFramebuffer(GL_FRAMEBUFFER,0);
        // Clear the background (not really necessary I suppose)
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        check();

        glBindBuffer(GL_ARRAY_BUFFER, state->buf);
        check();
        glUseProgram ( state->program );
        check();
        glBindTexture(GL_TEXTURE_2D,state->tex);
        check();
        glUniform4f(state->unif_color, 0.5, 0.5, 0.8, 1.0);
        glUniform2f(state->unif_scale, scale, scale);
        glUniform2f(state->unif_offset, x, y);
        glUniform2f(state->unif_centre, cx, cy);
        glUniform1i(state->unif_tex, 0); // I don't really understand this part, perhaps it relates to active texture?
        check();

        glDrawArrays ( GL_TRIANGLE_FAN, 0, 4 );
        check();

        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glFlush();
        glFinish();
        check();

        eglSwapBuffers(state->display, state->surface);
        check();
      }

      int main ()
      {
        bcm_host_init();

        // Clear application state
        memset(state, 0, sizeof(*state));

        // Start OGLES
        init_ogl(state);
        init_shaders(state);

        //draw_mandelbrot_to_texture(state);
        while (1)
        {
          draw_triangles(state);
        }
        return 0;
      }
      """
    return @output.join("\n")


exporter = new Exporter
console.log exporter.export()
